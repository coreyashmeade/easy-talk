import AVFoundation
import AppKit
import EasyTalkCore
import SwiftUI

/// Wires the core loop: hotkey → record → transcribe → clean → safety check → paste (PRD primary flow).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotkey = Hotkey()
    private let recorder = Recorder()
    private let pill = PillController()
    private let cleaner = Cleaner()
    private var transcriber: Transcriber?
    private var setupWindow: NSWindow?
    private var setupModel: SetupModel?

    private enum Phase { case idle, pending, recording(locked: Bool), processing }
    private var phase: Phase = .idle
    private var lastTapEnd = Date.distantPast
    private var tick: Timer?
    private var showPillWork: DispatchWorkItem?
    private var processingTask: Task<Void, Never>?
    private var modelsReady = false
    private var loadedEngine: SpeechEngineChoice?
    private var lastError: String?
    private var statusLine = "Starting…"
    private var permissionWatch: Timer?
    private var lastPermissions = (accessibility: false, microphone: false)

    private let minHold: TimeInterval = 0.3
    private let doubleTap: TimeInterval = 0.4
    private let maxSeconds = 300

    // MARK: launch

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.mainMenu = Self.makeMainMenu()  // gives Easy Talk's own windows working Edit shortcuts (⌘C, ⌘V, ⌘A)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Easy Talk")
        rebuildMenu()
        hotkey.onEvent = { [weak self] in self?.handle($0) }
        // Keep the menu's permission items current, and install the hotkey once Accessibility is granted.
        permissionWatch = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = (accessibility: Hotkey.isTrusted, microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized)
            guard now != self.lastPermissions else { return }
            self.lastPermissions = now
            if now.accessibility { self.hotkey.install() }
            self.rebuildMenu()
        }

        let installed = ModelStore.shared.isInstalled(ModelManifest.qwen)
            && (Settings.speechEngine == .apple || ModelStore.shared.isInstalled(ModelManifest.parakeet))
        Log.write("Launch. setupComplete=\(Settings.setupComplete) modelsInstalled=\(installed) trusted=\(Hotkey.isTrusted)")
        if installed { startEngines() }  // load models whenever they're present; the hotkey needs Accessibility
        if !Settings.setupComplete || !installed || !Hotkey.isTrusted
            || AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            openSetup()
        }
    }

    private var enginesStarting = false

    /// Loads the chosen speech engine and the cleanup model, and reports the result to the menu and to setup.
    private func startEngines() {
        if Hotkey.isTrusted { Log.write("Hotkey installed: \(hotkey.install())") }
        let engine = Settings.speechEngine
        if modelsReady && loadedEngine == engine { setupModel?.modelsReady = true; return }
        guard !enginesStarting else { return }
        enginesStarting = true
        modelsReady = false
        lastError = nil
        setupModel?.loadError = nil
        setupModel?.loading = true
        setStatus("Loading models…")
        Task {
            do {
                let t: Transcriber = engine == .parakeet ? ParakeetTranscriber() : AppleTranscriber()
                let start = Date()
                try await t.load()
                Log.write("Speech engine \(engine.rawValue) loaded in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
                if await !cleaner.isLoaded { try await cleaner.load() }
                Log.write("Cleanup model ready after \(Int(Date().timeIntervalSince(start) * 1000)) ms total")
                await MainActor.run {
                    self.enginesStarting = false
                    self.transcriber = t
                    self.loadedEngine = engine
                    self.modelsReady = true
                    self.setupModel?.loading = false
                    self.setupModel?.modelsReady = true
                    self.setStatus("Easy Talk is ready")
                }
            } catch {
                Log.write("Model load failed: \(error)")
                let details = "Easy Talk couldn't load its models.\n\(error.localizedDescription)\n\(error)\nLog: ~/Library/Logs/EasyTalk.log"
                await MainActor.run {
                    self.enginesStarting = false
                    self.lastError = details
                    self.setupModel?.loading = false
                    self.setupModel?.loadError = details
                    self.setStatus("Problem loading models: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func openMicrophoneSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
    }

    /// Credits for the bundled models and libraries (Parakeet's CC-BY-4.0 license requires attribution).
    @objc private func showAbout() {
        let credits = NSMutableAttributedString()
        let lines: [(String, String?)] = [
            ("On-device dictation. A personal proof of concept.\n\n", nil),
            ("Speech recognition: Parakeet TDT 0.6B v2 by NVIDIA, CC-BY-4.0\n", "https://huggingface.co/nvidia/parakeet-tdt-0.6b-v2"),
            ("Run with FluidAudio, Apache 2.0\n", "https://github.com/FluidInference/FluidAudio"),
            ("Text cleanup: Qwen 3.5 4B, Apache 2.0\n", "https://huggingface.co/mlx-community/Qwen3.5-4B-MLX-4bit"),
            ("Run with mlx-swift-lm, MIT\n", "https://github.com/ml-explore/mlx-swift-lm"),
        ]
        for (text, link) in lines {
            var attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11)]
            if let link { attrs[.link] = URL(string: link) }
            credits.append(NSAttributedString(string: text, attributes: attrs))
        }
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .applicationName: "Easy Talk"])
    }

    @objc private func copyErrorDetails() {
        guard let lastError else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastError, forType: .string)
    }

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Easy Talk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }

    // MARK: menu bar

    private func setStatus(_ s: String) { statusLine = s; rebuildMenu() }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: statusLine, action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: "Hold ⌃⌥Space to talk · double-tap to lock", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        // Missing permissions get a direct fix (PRD error path: permission revoked).
        if !Hotkey.isTrusted {
            let item = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        if AVCaptureDevice.authorizationStatus(for: .audio) != .authorized {
            let item = NSMenuItem(title: "Grant Microphone Access…", action: #selector(openMicrophoneSettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        let engineItem = NSMenuItem(title: "Speech engine", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for e in SpeechEngineChoice.allCases {
            let item = NSMenuItem(title: e.title, action: #selector(pickEngine(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = e.rawValue
            item.state = Settings.speechEngine == e ? .on : .off
            sub.addItem(item)
        }
        engineItem.submenu = sub
        menu.addItem(engineItem)
        if lastError != nil {
            let copy = NSMenuItem(title: "Copy Error Details", action: #selector(copyErrorDetails), keyEquivalent: "")
            copy.target = self
            menu.addItem(copy)
        }
        let setup = NSMenuItem(title: "Open Setup…", action: #selector(openSetupAction), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Easy Talk", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let lock = NSMenuItem(title: "Everything stays on this Mac", action: nil, keyEquivalent: "")
        lock.isEnabled = false
        menu.addItem(lock)
        menu.addItem(withTitle: "Quit Easy Talk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func pickEngine(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let e = SpeechEngineChoice(rawValue: raw), e != Settings.speechEngine else { return }
        if e == .parakeet && !ModelStore.shared.isInstalled(ModelManifest.parakeet) {
            Settings.speechEngine = e
            openSetup(step: 3)
            return
        }
        Settings.speechEngine = e
        Task {
            if e == .apple { _ = await AppleTranscriber.requestPermission() }
            await MainActor.run { self.startEngines() }
        }
        rebuildMenu()
    }

    @objc private func openSetupAction() { openSetup() }

    private func openSetup(step: Int = 0) {
        let model = SetupModel()
        model.step = step
        model.modelsReady = modelsReady
        model.loadError = lastError
        model.onModelsInstalled = { [weak self] in self?.startEngines() }
        model.onFinish = { [weak self] in
            Settings.setupComplete = true
            self?.setupWindow?.close()
            self?.setupWindow = nil
            self?.setupModel = nil
            Log.write("Setup finished. Hotkey installed: \(self?.hotkey.install() ?? false)")
        }
        setupModel = model
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 480), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "Easy Talk Setup"
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: SetupView(model: model))
        w.center()
        setupWindow = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    // MARK: hotkey state machine

    private func handle(_ e: Hotkey.Event) {
        switch (e, phase) {
        case (.pressStart, .idle):
            guard modelsReady else {
                pill.show(.problem(lastError != nil ? "Models didn't load · see menu bar" : "Still loading models…"), hideAfter: 2)
                return
            }
            let isDoubleTap = Date().timeIntervalSince(lastTapEnd) < doubleTap
            startRecording(locked: isDoubleTap)
        case (.pressEnd(let held), .pending):
            // Released before 0.3 s: ignore (no sound, no pill), but remember it for double-tap.
            _ = recorder.stop()
            showPillWork?.cancel()
            phase = .idle
            hotkey.escapeActive = false
            if held < minHold { lastTapEnd = Date() }
        case (.pressEnd, .recording(locked: false)):
            finishRecording()
        case (.pressStart, .recording(locked: true)):
            finishRecording()
        case (.escape, .pending), (.escape, .recording):
            _ = recorder.stop()
            cancel()
        case (.escape, .processing):
            processingTask?.cancel()
            cancel()
        default:
            break  // busy: presses while processing are ignored
        }
    }

    private func startRecording(locked: Bool) {
        do { try recorder.start() } catch {
            pill.show(.problem("Microphone unavailable"), hideAfter: 2)
            return
        }
        hotkey.escapeActive = true
        if locked {
            phase = .recording(locked: true)
            playSound(start: true)
            pill.show(.locked(seconds: 0, level: 0))
            startTicking()
        } else {
            phase = .pending
            let work = DispatchWorkItem { [weak self] in
                guard let self, case .pending = self.phase else { return }
                self.phase = .recording(locked: false)
                self.playSound(start: true)
                self.pill.show(.listening(seconds: 0, level: 0))
                self.startTicking()
            }
            showPillWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + minHold, execute: work)
        }
    }

    private func startTicking() {
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, case .recording(let locked) = self.phase else { return }
            let s = Int(self.recorder.elapsed)
            let level = Double(self.recorder.level)
            if s >= self.maxSeconds { self.finishRecording(); return }
            if s >= self.maxSeconds - 30 { self.pill.show(.warning(secondsLeft: self.maxSeconds - s)) }
            else { self.pill.show(locked ? .locked(seconds: s, level: level) : .listening(seconds: s, level: level)) }
        }
    }

    private func cancel() {
        tick?.invalidate()
        phase = .idle
        hotkey.escapeActive = false
        pill.show(.cancelled, hideAfter: 1)
    }

    private func finishRecording() {
        tick?.invalidate()
        let (samples, peak) = recorder.stop()
        playSound(start: false)
        phase = .processing
        pill.show(.thinking)
        let words = Settings.wordList
        let transcriber = self.transcriber
        let audioSeconds = Double(samples.count) / Recorder.sampleRate
        let released = Date()
        processingTask = Task { [weak self] in
            guard let self else { return }
            // Silence-only recordings paste nothing.
            guard peak > 0.008, let transcriber,
                  let result = await Pipeline.run(samples, transcriber: transcriber, cleaner: self.cleaner, wordList: words) else {
                Log.write(String(format: "Dictation: %.1f s audio, no speech detected (peak %.4f)", audioSeconds, peak))
                await MainActor.run { self.finish(.noSpeech) }
                return
            }
            if Task.isCancelled { return }
            Log.write(String(format: "Dictation: %.1f s audio, transcribed %d ms, cleaned %d ms, fallback=%@",
                             audioSeconds, result.transcribeMs, result.totalMs, result.fallbackReason ?? "none"))
            await MainActor.run {
                let outcome = Paster.deliver(result.final)
                Log.write("Delivered: \(outcome == .pasted ? "pasted" : "copied") in \(Int(Date().timeIntervalSince(released) * 1000)) ms after release")
                if outcome == .copied { self.finish(.copied) }
                else if result.fallbackReason != nil { self.finish(.fallback("Cleanup skipped")) }
                else { self.finish(.done(words: TextRules.wordCount(result.final))) }
            }
        }
    }

    private func finish(_ state: PillState) {
        phase = .idle
        hotkey.escapeActive = false
        pill.show(state, hideAfter: state == .copied ? 2 : 1.2)
    }

    private func playSound(start: Bool) {
        guard Settings.soundsOn else { return }
        let s = NSSound(named: start ? "Tink" : "Pop")
        s?.volume = 0.25
        s?.play()
    }
}

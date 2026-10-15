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
    private var statusLine = "Starting…"

    private let minHold: TimeInterval = 0.3
    private let doubleTap: TimeInterval = 0.4
    private let maxSeconds = 300

    // MARK: launch

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Easy Talk")
        rebuildMenu()
        hotkey.onEvent = { [weak self] in self?.handle($0) }

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

    private func startEngines() {
        if Hotkey.isTrusted { Log.write("Hotkey installed: \(hotkey.install())") }
        guard !enginesStarting, !modelsReady else { return }
        enginesStarting = true
        setStatus("Loading models…")
        let engine = Settings.speechEngine
        Task {
            do {
                let t: Transcriber = engine == .parakeet ? ParakeetTranscriber() : AppleTranscriber()
                let start = Date()
                try await t.load()
                Log.write("Speech engine \(engine.rawValue) loaded in \(Int(Date().timeIntervalSince(start) * 1000)) ms")
                try await cleaner.load()
                Log.write("Cleanup model loaded in \(Int(Date().timeIntervalSince(start) * 1000)) ms total")
                await MainActor.run {
                    self.enginesStarting = false
                    self.transcriber = t
                    self.modelsReady = true
                    self.setupModel?.modelsReady = true
                    self.setStatus("Easy Talk is ready")
                }
            } catch {
                Log.write("Model load failed: \(error)")
                await MainActor.run {
                    self.enginesStarting = false
                    self.setStatus("Problem loading models: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: menu bar

    private func setStatus(_ s: String) { statusLine = s; rebuildMenu() }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: statusLine, action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(withTitle: "Hold ⌃⌥Space to talk · double-tap to lock", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
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
        let setup = NSMenuItem(title: "Open Setup…", action: #selector(openSetupAction), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        menu.addItem(.separator())
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
        modelsReady = false
        Task {
            if e == .apple { _ = await AppleTranscriber.requestPermission() }
            let t: Transcriber = e == .parakeet ? ParakeetTranscriber() : AppleTranscriber()
            do {
                try await t.load()
                await MainActor.run { self.transcriber = t; self.modelsReady = true; self.setStatus("Easy Talk is ready") }
            } catch {
                await MainActor.run { self.setStatus("Problem: \(error.localizedDescription)") }
            }
        }
        rebuildMenu()
    }

    @objc private func openSetupAction() { openSetup() }

    private func openSetup(step: Int = 0) {
        let model = SetupModel()
        model.step = step
        model.modelsReady = modelsReady
        model.onModelsInstalled = { [weak self] in
            guard let self else { return }
            if !self.modelsReady || self.transcriber == nil { self.startEngines() }
        }
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
            guard modelsReady else { pill.show(.problem(statusLine.hasPrefix("Problem") ? "Models failed to load" : "Still loading models…"), hideAfter: 1.5); return }
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
        processingTask = Task { [weak self] in
            guard let self else { return }
            // Silence-only recordings paste nothing.
            guard peak > 0.008, let transcriber,
                  let rawText = try? await transcriber.transcribe(samples),
                  !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run { self.finish(.noSpeech) }
                return
            }
            if Task.isCancelled { return }
            let raw = TextRules.applyWordList(rawText, words: words)
            var final = raw
            var fallbackWhy: String?
            do {
                let cleaned = try await withTimeout(Cleanup.timeoutSeconds) { try await self.cleaner.clean(raw, wordList: words) }
                if let why = Cleanup.rejectionReason(raw: raw, cleaned: cleaned) { fallbackWhy = why } else { final = cleaned }
            } catch {
                fallbackWhy = Task.isCancelled ? nil : "Cleanup skipped"
            }
            if Task.isCancelled { return }
            let text = final
            let why = fallbackWhy
            await MainActor.run {
                let outcome = Paster.deliver(text)
                if outcome == .copied { self.finish(.copied) }
                else if why != nil { self.finish(.fallback("Cleanup skipped")) }
                else { self.finish(.done(words: TextRules.wordCount(text))) }
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

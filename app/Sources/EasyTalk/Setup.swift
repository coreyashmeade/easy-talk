import AVFoundation
import AppKit
import EasyTalkCore
import SwiftUI

/// First-run setup (R27): Welcome → Permissions → Speech engine → Download → Try it.
/// Setup can't finish until Microphone and Accessibility are granted.
final class SetupModel: ObservableObject {
    @Published var step = 0
    @Published var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @Published var axGranted = Hotkey.isTrusted
    @Published var engine: SpeechEngineChoice = Settings.speechEngine
    @Published var speechGranted = false
    @Published var progress: [String: Double] = [:]
    @Published var downloadError: String?
    @Published var downloading = false
    @Published var modelsReady = false
    @Published var loading = false
    @Published var loadError: String?
    @Published var practiceText = ""

    var onModelsInstalled: (() -> Void)?
    var onFinish: (() -> Void)?
    private var poll: Timer?

    init() {
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.axGranted = Hotkey.isTrusted
            self.micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        }
    }

    var permissionsOK: Bool { micGranted && axGranted }

    func requestMic() {
        AVCaptureDevice.requestAccess(for: .audio) { ok in DispatchQueue.main.async { self.micGranted = ok } }
    }

    func openAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func chooseEngine(_ e: SpeechEngineChoice) {
        engine = e
        Settings.speechEngine = e
        if e == .apple { Task { let ok = await AppleTranscriber.requestPermission(); await MainActor.run { self.speechGranted = ok } } }
    }

    func download() {
        guard !downloading else { return }
        downloading = true
        downloadError = nil
        loadError = nil
        var models: [(String, PinnedModel)] = [("Qwen 3.5 4B cleanup model", ModelManifest.qwen)]
        if engine == .parakeet { models.insert(("Parakeet speech model", ModelManifest.parakeet), at: 0) }
        Task {
            do {
                for (name, m) in models where !ModelStore.shared.isInstalled(m) {
                    try await ModelStore.shared.install(m) { p in DispatchQueue.main.async { self.progress[name] = p } }
                }
                await MainActor.run {
                    for (name, _) in models { self.progress[name] = 1 }
                    self.downloading = false
                    self.onModelsInstalled?()
                }
            } catch {
                await MainActor.run { self.downloadError = error.localizedDescription; self.downloading = false }
            }
        }
    }

    var downloadsDone: Bool {
        ModelStore.shared.isInstalled(ModelManifest.qwen) && (engine == .apple || ModelStore.shared.isInstalled(ModelManifest.parakeet))
    }
}

struct SetupView: View {
    @ObservedObject var model: SetupModel

    var body: some View {
        VStack(spacing: 0) {
            HStack { Spacer(); ZigZagMark() }.padding(.horizontal, 14).frame(height: 30)
            Group {
                switch model.step {
                case 0: welcome
                case 1: permissions
                case 2: engine
                case 3: download
                default: tryIt
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 56)
            Divider()
            footer
        }
        .frame(width: 640, height: 480)
        .background(Brand.surface)
        .foregroundStyle(Brand.ink)
    }

    private var welcome: some View {
        VStack(spacing: 14) {
            Spacer()
            RoundedRectangle(cornerRadius: 18).fill(Brand.pill).frame(width: 72, height: 72)
                .overlay(Image(systemName: "mic").font(.system(size: 30, weight: .medium)).foregroundStyle(Brand.accentStrong))
            Text("Welcome to Easy Talk").font(.system(size: 26, weight: .bold))
            Text("Hold a key, say what you mean, and clean, formatted text appears wherever you're typing.")
                .font(.system(size: 15)).multilineTextAlignment(.center).foregroundStyle(Brand.pillMuted)
            HStack(spacing: 22) {
                Label("Stays on this Mac", systemImage: "lock")
                Label("Cleaned and formatted", systemImage: "text.alignleft")
                Label("Works in any app", systemImage: "bolt")
            }.font(.system(size: 13)).padding(.top, 8)
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var permissions: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Two permissions, nothing more", "macOS asks for these so Easy Talk can hear you and paste for you.")
            permissionCard("mic", "Microphone", "Only while you hold the shortcut. Never always listening.",
                           granted: model.micGranted, action: model.requestMic, actionTitle: "Allow")
            permissionCard("keyboard", "Accessibility", "Lets Easy Talk paste at your cursor and catch the shortcut.",
                           granted: model.axGranted, action: model.openAccessibility, actionTitle: "Open Settings")
            Label("Easy Talk can't see your screen or read other apps.", systemImage: "lock").font(.system(size: 13)).foregroundStyle(Brand.pillMuted)
        }.padding(.top, 12)
    }

    private var engine: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading("Choose how Easy Talk hears you", "Both run entirely on this Mac. You can switch anytime from the menu bar.")
            HStack(spacing: 14) {
                engineCard(.parakeet, "Fastest and very accurate for English. Adds punctuation for you.", "One-time download · about 460 MB", badge: "Recommended")
                engineCard(.apple, "Built into macOS. Nothing extra to download.", "Asks for Speech Recognition access", badge: nil)
            }
        }.padding(.top, 12)
    }

    private var download: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Getting the models ready", "A one-time download. After this, Easy Talk never goes online.")
            let names = (model.engine == .parakeet ? ["Parakeet speech model"] : []) + ["Qwen 3.5 4B cleanup model"]
            ForEach(names, id: \.self) { name in
                let p = model.progress[name] ?? 0
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(name).bold(); Spacer(); Text(p >= 1 ? "Verified" : "\(Int(p * 100))%") }
                    ProgressView(value: p).tint(Brand.button)
                }
                .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            if let err = model.downloadError { Text(err).foregroundStyle(Brand.accentStrong).font(.system(size: 13)) }
            loadStatus
            Label("Each file is checked against a known fingerprint before it's used.", systemImage: "checkmark.shield")
                .font(.system(size: 13)).foregroundStyle(Brand.pillMuted)
        }
        .padding(.top, 12)
        .onAppear { if !model.modelsReady { model.download() } }
    }

    /// After downloading, the models are loaded once so setup only continues when they actually work.
    @ViewBuilder private var loadStatus: some View {
        if let err = model.loadError {
            VStack(alignment: .leading, spacing: 8) {
                Label(err.components(separatedBy: "\n").prefix(2).joined(separator: " "), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Brand.accentStrong).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button("Copy details") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(err, forType: .string)
                    }
                    Button("Try again") { model.download() }
                }
                .buttonStyle(.bordered)
            }
        } else if model.modelsReady {
            Label("Models loaded and working", systemImage: "checkmark.circle.fill").bold()
        } else if model.loading {
            Label("Loading models to check they work… (first time can take about 15 seconds)", systemImage: "hourglass")
                .font(.system(size: 13)).foregroundStyle(Brand.pillMuted)
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Try it", "Click in the box, hold ⌃ ⌥ Space and say a few things you need to do today.")
            loadStatus
            TextEditor(text: $model.practiceText)
                .font(.system(size: 14)).scrollContentBackground(.hidden).padding(8)
                .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.button, lineWidth: 2))
                .frame(height: 170)
        }.padding(.top, 8)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<5) { i in Capsule().fill(i == model.step ? Brand.button : Brand.pillMuted.opacity(0.25)).frame(width: i == model.step ? 18 : 6, height: 6) }
            }
            Spacer()
            if model.step > 0 { Button("Back") { model.step -= 1 }.buttonStyle(.plain).padding(.horizontal, 14) }
            Button(nextTitle) { next() }
                .buttonStyle(.plain).bold().padding(.vertical, 7).padding(.horizontal, 18)
                .background(nextEnabled ? Brand.button : Brand.button.opacity(0.4)).clipShape(RoundedRectangle(cornerRadius: 7))
                .disabled(!nextEnabled)
        }
        .padding(.horizontal, 22).frame(height: 64)
    }

    private var nextTitle: String { ["Get started", "Continue", "Continue", "Continue", "Finish"][min(model.step, 4)] }

    private var nextEnabled: Bool {
        switch model.step {
        case 1: return model.permissionsOK
        case 2: return model.engine == .parakeet || model.speechGranted
        case 3: return model.downloadsDone && !model.downloading && model.modelsReady
        default: return true
        }
    }

    private func next() { if model.step < 4 { model.step += 1 } else { model.onFinish?() } }

    private func heading(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 22, weight: .bold))
            Text(sub).font(.system(size: 14)).foregroundStyle(Brand.pillMuted)
        }
    }

    private func permissionCard(_ icon: String, _ title: String, _ desc: String, granted: Bool, action: @escaping () -> Void, actionTitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(Brand.accentStrong).frame(width: 36, height: 36)
                .background(Brand.pill.opacity(0.35)).clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) { Text(title).bold(); Text(desc).foregroundStyle(Brand.pillMuted).font(.system(size: 13)) }
            Spacer()
            if granted { Label("Allowed", systemImage: "checkmark").bold() }
            else {
                Button(actionTitle, action: action).buttonStyle(.plain).bold().padding(.vertical, 6).padding(.horizontal, 14)
                    .background(Brand.button).clipShape(RoundedRectangle(cornerRadius: 7))
            }
        }
        .padding(14).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func engineCard(_ e: SpeechEngineChoice, _ desc: String, _ meta: String, badge: String?) -> some View {
        Button { model.chooseEngine(e) } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(e.title).font(.system(size: 15, weight: .semibold))
                    Spacer()
                    if let badge { Text(badge).font(.system(size: 11, weight: .semibold)).padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Brand.pill.opacity(0.4)).clipShape(Capsule()) }
                }
                Text(desc).foregroundStyle(Brand.pillMuted).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Text(meta).foregroundStyle(Brand.pillMuted).font(.system(size: 12))
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(model.engine == e ? Brand.button : Brand.pillMuted.opacity(0.2), lineWidth: 2))
        }.buttonStyle(.plain)
    }
}

import CryptoKit
import EasyTalkCore
import Foundation

enum ModelError: LocalizedError {
    case checksumMismatch(String)
    case download(String)

    var errorDescription: String? {
        switch self {
        case .checksumMismatch(let f): return "\(f) failed its checksum and was deleted. Try the download again."
        case .download(let m): return "Download failed: \(m)"
        }
    }
}

/// Downloads pinned model files from their official repos, verifies every file's SHA-256 (R40),
/// and stores them under Application Support. This is the only code in the app that uses the network (R39).
final class ModelStore {
    static let shared = ModelStore()

    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("EasyTalk/Models", isDirectory: true)

    /// Folder names match what the libraries expect when loading from disk.
    func folder(for model: PinnedModel) -> URL {
        root.appendingPathComponent(String(model.repo.split(separator: "/").last!), isDirectory: true)
    }

    /// Already-downloaded copies (from the M2 spikes) we can verify and copy instead of downloading again.
    private func localSources(for model: PinnedModel) -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if model.repo == ModelManifest.qwen.repo {
            return [home.appendingPathComponent(".cache/huggingface/hub/models--mlx-community--Qwen3.5-4B-MLX-4bit/snapshots/\(model.revision)")]
        }
        return [home.appendingPathComponent("Library/Application Support/FluidAudio/Models/parakeet-tdt-0.6b-v2-coreml")]
    }

    private var verifiedMarker: String { ".verified" }

    func isInstalled(_ model: PinnedModel) -> Bool {
        let dir = folder(for: model)
        guard let marker = try? String(contentsOf: dir.appendingPathComponent(verifiedMarker), encoding: .utf8),
              marker == model.revision else { return false }
        return model.files.allSatisfy { f in
            let size = (try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(f.path).path)[.size] as? Int64) ?? -1
            return size == f.size
        }
    }

    /// Installs every file of `model`, verifying each checksum. `progress` reports 0...1.
    func install(_ model: PinnedModel, progress: @escaping @Sendable (Double) -> Void) async throws {
        let fm = FileManager.default
        let dir = folder(for: model)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        var done: Int64 = 0
        let total = model.totalBytes
        for file in model.files {
            let dest = dir.appendingPathComponent(file.path)
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: dest.path), (try? Self.sha256(of: dest)) == file.sha256 {
                done += file.size; progress(Double(done) / Double(total)); continue
            }
            try? fm.removeItem(at: dest)
            // Prefer a verified local copy; otherwise download from the pinned URL.
            var placed = false
            for src in localSources(for: model) {
                let candidate = src.appendingPathComponent(file.path).resolvingSymlinksInPath()
                if fm.fileExists(atPath: candidate.path), (try? Self.sha256(of: candidate)) == file.sha256 {
                    try fm.copyItem(at: candidate, to: dest)
                    placed = true
                    break
                }
            }
            if !placed {
                let base = done
                let tmp = try await download(model.url(for: file)) { fraction in
                    progress(Double(base + Int64(Double(file.size) * fraction)) / Double(total))
                }
                guard (try? Self.sha256(of: tmp)) == file.sha256 else {
                    try? fm.removeItem(at: tmp)
                    throw ModelError.checksumMismatch(file.path)
                }
                try fm.moveItem(at: tmp, to: dest)
            }
            done += file.size
            progress(Double(done) / Double(total))
        }
        try model.revision.write(to: dir.appendingPathComponent(verifiedMarker), atomically: true, encoding: .utf8)
    }

    private func download(_ url: URL, progress: @escaping (Double) -> Void) async throws -> URL {
        let delegate = DownloadProgress(progress)
        let (tmp, response) = try await URLSession.shared.download(from: url, delegate: delegate)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ModelError.download("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) for \(url.lastPathComponent)")
        }
        let kept = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.moveItem(at: tmp, to: kept)
        return kept
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 8 << 20), !chunk.isEmpty { hasher.update(data: chunk) }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private final class DownloadProgress: NSObject, URLSessionTaskDelegate {
    let onProgress: (Double) -> Void
    var observation: NSKeyValueObservation?
    init(_ p: @escaping (Double) -> Void) { onProgress = p }
    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in self?.onProgress(p.fractionCompleted) }
    }
}

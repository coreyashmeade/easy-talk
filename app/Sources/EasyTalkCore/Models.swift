import Foundation

public struct PinnedFile: Sendable, Equatable {
    public let path: String
    public let sha256: String
    public let size: Int64
    public init(path: String, sha256: String, size: Int64) {
        self.path = path
        self.sha256 = sha256
        self.size = size
    }
}

public struct PinnedModel: Sendable {
    public let repo: String
    public let revision: String
    public let files: [PinnedFile]
    public var totalBytes: Int64 { files.reduce(0) { $0 + $1.size } }

    /// Official download URL for one pinned file (Hugging Face, exact revision).
    public func url(for file: PinnedFile) -> URL {
        let encoded = file.path.split(separator: "/").map {
            String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        return URL(string: "https://huggingface.co/\(repo)/resolve/\(revision)/\(encoded)")!
    }
}

public enum SpeechEngineChoice: String, CaseIterable, Sendable {
    case parakeet
    case apple

    public var title: String { self == .parakeet ? "Parakeet" : "Apple speech" }
}

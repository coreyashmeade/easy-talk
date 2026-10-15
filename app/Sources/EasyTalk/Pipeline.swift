import EasyTalkCore
import Foundation

/// Speech → text → cleanup → safety check. Shared by the hotkey flow and the self-test.
enum Pipeline {
    struct Result {
        let raw: String
        let final: String
        /// Why the cleaned text was rejected in favor of the raw transcript, if it was.
        let fallbackReason: String?
        let transcribeMs: Int
        let totalMs: Int
    }

    /// Returns nil when no speech was found.
    static func run(_ samples: [Float], transcriber: Transcriber, cleaner: Cleaner, wordList: [String]) async -> Result? {
        let start = Date()
        guard let rawText = try? await transcriber.transcribe(samples),
              !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let transcribeMs = Int(Date().timeIntervalSince(start) * 1000)
        let raw = TextRules.applyWordList(rawText, words: wordList)
        var final = raw
        var reason: String?
        do {
            let cleaned = try await withTimeout(Cleanup.timeoutSeconds) { try await cleaner.clean(raw, wordList: wordList) }
            if let why = Cleanup.rejectionReason(raw: raw, cleaned: cleaned) { reason = why } else { final = cleaned }
        } catch {
            reason = "cleanup unavailable"
        }
        return Result(raw: raw, final: final, fallbackReason: reason, transcribeMs: transcribeMs,
                      totalMs: Int(Date().timeIntervalSince(start) * 1000))
    }
}

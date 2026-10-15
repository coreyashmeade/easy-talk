import AVFoundation
import EasyTalkCore
import FluidAudio
import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Speech
import Tokenizers

// MARK: - Speech to text

protocol Transcriber: AnyObject {
    func load() async throws
    func transcribe(_ samples: [Float]) async throws -> String
}

/// Parakeet v2 (English) via FluidAudio, loaded from our verified folder with networking disabled.
final class ParakeetTranscriber: Transcriber {
    private var manager: AsrManager?

    func load() async throws {
        ModelHub.offlineMode = true  // never let the library fetch anything (R39)
        let dir = ModelStore.shared.folder(for: ModelManifest.parakeet)
        let models = try await AsrModels.load(from: dir, version: .v2)
        let m = AsrManager(config: .default)
        try await m.loadModels(models)
        manager = m
        _ = try await transcribe(Array(repeating: 0, count: 16000))  // warm up
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let manager else { throw NSError(domain: "EasyTalk", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech model not loaded"]) }
        var state = try TdtDecoderState()
        return try await manager.transcribe(samples, decoderState: &state).text
    }
}

/// Apple's built-in speech recognition, forced to run on-device.
final class AppleTranscriber: Transcriber {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func load() async throws {
        guard let recognizer, recognizer.supportsOnDeviceRecognition else {
            throw NSError(domain: "EasyTalk", code: 3, userInfo: [NSLocalizedDescriptionKey: "On-device Apple speech isn't available on this Mac"])
        }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let recognizer else { return "" }
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return "" }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        request.shouldReportPartialResults = false
        request.append(buffer)
        request.endAudio()
        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal { finished = true; cont.resume(returning: result.bestTranscription.formattedString) }
                else if let error { finished = true; cont.resume(throwing: error) }
            }
        }
    }

    static func requestPermission() async -> Bool {
        await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) } }
    }
}

// MARK: - Cleanup (Qwen 3.5 4B)

/// The cleanup model. Text in, text out: no tools, no network, no access to anything else (R36).
actor Cleaner {
    private var container: ModelContainer?

    var isLoaded: Bool { container != nil }

    func load() async throws {
        let dir = ModelStore.shared.folder(for: ModelManifest.qwen)
        container = try await loadModelContainer(from: dir, using: #huggingFaceTokenizerLoader())
        _ = try await cleanPiece("um this is a warm up", wordList: [])
    }

    /// Cleans a transcript. Spoken commands are handled by rules; each piece is cleaned separately.
    func clean(_ transcript: String, wordList: [String]) async throws -> String {
        var cleaned: [(String, TextRules.Break?)] = []
        for piece in TextRules.pieces(from: transcript) {
            cleaned.append((try await cleanPiece(piece.text, wordList: wordList), piece.breakAfter))
        }
        return TextRules.join(cleaned)
    }

    private func cleanPiece(_ text: String, wordList: [String]) async throws -> String {
        guard let container else { throw NSError(domain: "EasyTalk", code: 4, userInfo: [NSLocalizedDescriptionKey: "Cleanup model not loaded"]) }
        let session = ChatSession(
            container,
            instructions: Cleanup.systemPrompt(wordList: wordList),
            generateParameters: GenerateParameters(maxTokens: max(64, TextRules.wordCount(text) * 3 + 40), temperature: 0),
            additionalContext: ["enable_thinking": false]
        )
        return try await session.respond(to: Cleanup.userMessage(text)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Runs `work` but gives up after `seconds`.
func withTimeout<T: Sendable>(_ seconds: Double, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw NSError(domain: "EasyTalk", code: 5, userInfo: [NSLocalizedDescriptionKey: "Cleanup took too long"])
        }
        let first = try await group.next()!
        group.cancelAll()
        return first
    }
}

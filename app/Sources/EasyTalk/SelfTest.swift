import AppKit
import EasyTalkCore
import FluidAudio
import Foundation

/// `EasyTalk --selftest <cases.json> [results.json]`: runs the real pipeline on synthesized speech for every
/// test case, plus clipboard-restore and checksum checks. Never presses keys or pastes into other apps.
enum SelfTest {
    private struct Suite: Decodable { let word_list: [String]; let cases: [Case] }
    private struct Case: Decodable {
        let id: String
        let input: String
        let format: String
        let must_include: [String]
        let must_exclude: [String]
        let min_paragraphs: Int?
    }
    private struct Row: Encodable {
        let id: String; let transcript: String; let output: String; let fallback: String?
        let pass: Bool; let failures: [String]; let totalMs: Int; let audioSeconds: Double
    }

    static func run(arguments: [String]) async -> Int32 {
        guard let casesPath = arguments.first else { print("usage: EasyTalk --selftest <cases.json> [results.json]"); return 2 }
        var failed = 0
        do {
            let suite = try JSONDecoder().decode(Suite.self, from: Data(contentsOf: URL(fileURLWithPath: casesPath)))
            let transcriber = ParakeetTranscriber()
            let cleaner = Cleaner()
            try await transcriber.load()
            try await cleaner.load()

            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("EasyTalkSelfTest-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tmp) }

            var rows: [Row] = []
            for c in suite.cases {
                let wav = tmp.appendingPathComponent("\(c.id).wav")
                try speak(c.input, to: wav)
                let samples = try AudioConverter().resampleAudioFile(path: wav.path)
                try? FileManager.default.removeItem(at: wav)
                guard let r = await Pipeline.run(samples, transcriber: transcriber, cleaner: cleaner, wordList: suite.word_list) else {
                    rows.append(Row(id: c.id, transcript: "", output: "", fallback: nil, pass: false, failures: ["no speech"], totalMs: 0,
                                    audioSeconds: Double(samples.count) / 16000))
                    continue
                }
                let f = score(c, r.final)
                rows.append(Row(id: c.id, transcript: r.raw, output: r.final, fallback: r.fallbackReason, pass: f.isEmpty, failures: f,
                                totalMs: r.totalMs, audioSeconds: Double(samples.count) / 16000))
                print(String(format: "%@ %-4@ %5d ms  %@", f.isEmpty ? "PASS" : "FAIL", c.id, r.totalMs, f.joined(separator: "; ")))
            }
            failed += rows.filter { !$0.pass }.count
            let times = rows.map(\.totalMs).sorted()
            print("Cleanup cases: \(rows.count - rows.filter { !$0.pass }.count)/\(rows.count) passed. Median \(times[times.count / 2]) ms, max \(times.last ?? 0) ms.")

            // 30-second dictation timing (G3).
            let long = suite.cases.filter { ["P1", "P2", "P3"].contains($0.id) }.map(\.input).joined(separator: " ")
            let longWav = tmp.appendingPathComponent("long.wav")
            try speak(long + " " + long, to: longWav)
            let longSamples = try AudioConverter().resampleAudioFile(path: longWav.path)
            try? FileManager.default.removeItem(at: longWav)
            if let r = await Pipeline.run(longSamples, transcriber: transcriber, cleaner: cleaner, wordList: suite.word_list) {
                let secs = Double(longSamples.count) / 16000
                let ok = r.totalMs <= 2000
                if !ok { failed += 1 }
                print(String(format: "%@ G3   %.0f s of speech processed in %d ms (target 2000 ms)", ok ? "PASS" : "FAIL", secs, r.totalMs))
            }

            if arguments.count > 1 {
                let enc = JSONEncoder()
                enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
                try enc.encode(rows).write(to: URL(fileURLWithPath: arguments[1]))
            }
        } catch {
            print("FAIL setup: \(error)")
            return 1
        }

        failed += await clipboardRestoreCheck() ? 0 : 1
        failed += checksumCheck() ? 0 : 1
        print(failed == 0 ? "ALL CHECKS PASSED" : "\(failed) CHECK(S) FAILED")
        return failed == 0 ? 0 : 1
    }

    private static func speak(_ text: String, to url: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        p.arguments = ["-o", url.path, "--data-format=LEF32@16000", text]
        try p.run()
        p.waitUntilExit()
    }

    /// R23: the user's clipboard comes back after a paste.
    private static func clipboardRestoreCheck() async -> Bool {
        let pb = NSPasteboard.general
        let original = pb.string(forType: .string)
        pb.clearContents()
        pb.setString("ABC", forType: .string)
        _ = await MainActor.run { Paster.deliver("1. Call Sam\n2. Send the deck", pressKeys: false, assumeTarget: true) }
        let during = pb.string(forType: .string)
        let hadRich = pb.data(forType: .html) != nil && pb.data(forType: .rtf) != nil
        try? await Task.sleep(for: .seconds(1.5))
        let after = pb.string(forType: .string)
        let ok = during?.contains("Call Sam") == true && hadRich && after == "ABC"
        print("\(ok ? "PASS" : "FAIL") R23  clipboard holds rich + plain text during paste, then restored (\(after ?? "nil"))")
        pb.clearContents()
        if let original { pb.setString(original, forType: .string) }
        return ok
    }

    /// R40: a model file that doesn't match its pinned checksum is rejected.
    private static func checksumCheck() -> Bool {
        let model = ModelManifest.qwen
        guard let file = model.files.first(where: { $0.path == "config.json" }) else { return false }
        let real = ModelStore.shared.folder(for: model).appendingPathComponent(file.path)
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("tampered-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: copy) }
        guard (try? FileManager.default.copyItem(at: real, to: copy)) != nil else { return false }
        let genuineAccepted = ModelStore.verify(copy, against: file)
        if let h = try? FileHandle(forWritingTo: copy) { h.seekToEndOfFile(); h.write(Data(" ".utf8)); try? h.close() }
        let tamperedRejected = !ModelStore.verify(copy, against: file)
        let ok = genuineAccepted && tamperedRejected
        print("\(ok ? "PASS" : "FAIL") R40  genuine model file accepted, tampered copy rejected")
        return ok
    }

    private static func containsWord(_ hay: String, _ needle: String) -> Bool {
        let n = needle.lowercased()
        if n.allSatisfy({ $0.isLetter || $0 == " " }) {
            return hay.lowercased().range(of: "\\b" + NSRegularExpression.escapedPattern(for: n) + "\\b", options: .regularExpression) != nil
        }
        return hay.lowercased().contains(n)
    }

    private static func score(_ c: Case, _ out: String) -> [String] {
        var f: [String] = []
        for m in c.must_include where !out.lowercased().contains(m.lowercased()) { f.append("missing '\(m)'") }
        for m in c.must_exclude where containsWord(out, m) { f.append("contains '\(m)'") }
        let lines = out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        let numbered = lines.filter { $0.range(of: #"^\d+[\.\)] "#, options: .regularExpression) != nil }.count
        let bullets = lines.filter { $0.hasPrefix("- ") || $0.hasPrefix("• ") }.count
        let paragraphs = out.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        switch c.format {
        case "numbered": if numbered < 2 { f.append("expected numbered list") }
        case "bullets": if bullets < 2 && numbered < 2 { f.append("expected list") }
        case "plain": if numbered + bullets >= 2 { f.append("unexpected list") }
        case "lines": if !out.contains("\n") { f.append("expected line break") }
        default: break
        }
        if let mp = c.min_paragraphs, paragraphs < mp, !(c.format == "paragraphs" && out.contains("\n")) {
            f.append("expected \(mp)+ paragraphs")
        }
        return f
    }
}

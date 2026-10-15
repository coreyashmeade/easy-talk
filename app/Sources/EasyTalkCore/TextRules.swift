import Foundation

/// Deterministic text handling that runs before and after the cleanup model.
/// Spoken formatting commands are handled here, not by the model (M2 finding: the model ignores them).
public enum TextRules {
    public enum Break: Equatable, Sendable { case line, paragraph }

    public struct Piece: Equatable, Sendable {
        public let text: String
        public let breakAfter: Break?
    }

    /// Splits a raw transcript at spoken "new line" / "new paragraph" and turns spoken "bullet" into "- " items.
    /// Each piece is cleaned separately and joined with real breaks.
    public static func pieces(from transcript: String) -> [Piece] {
        var s = transcript
        let rules: [(String, String)] = [
            (#"[\s,.]*\bnew paragraph\b[\s,.:]*"#, " ⟦PARA⟧ "),
            (#"[\s,.]*\bnew line\b[\s,.:]*"#, " ⟦NL⟧ "),
            (#"(^|[.!?]\s*|\n)\s*bullet\b[\s,.:]*"#, "$1\n- "),
        ]
        for (pattern, template) in rules {
            let re = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
        }
        var result: [Piece] = []
        var rest = Substring(s)
        while true {
            let para = rest.range(of: "⟦PARA⟧"), nl = rest.range(of: "⟦NL⟧")
            let next = [para, nl].compactMap { $0 }.min(by: { $0.lowerBound < $1.lowerBound })
            let chunk = (next.map { rest[..<$0.lowerBound] } ?? rest).trimmingCharacters(in: .whitespacesAndNewlines)
            let brk: Break? = next.map { $0 == para ? .paragraph : .line }
            if !chunk.isEmpty {
                result.append(Piece(text: chunk, breakAfter: brk))
            } else if let brk, let last = result.popLast() {
                result.append(Piece(text: last.text, breakAfter: brk))
            }
            guard let next else { break }
            rest = rest[next.upperBound...]
        }
        if let last = result.popLast() { result.append(Piece(text: last.text, breakAfter: nil)) }
        return result
    }

    public static func join(_ cleaned: [(String, Break?)]) -> String {
        var out = ""
        for (text, brk) in cleaned {
            out += text
            switch brk {
            case .paragraph: out += "\n\n"
            case .line: out += "\n"
            case nil: break
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Applies the user's word list: any case-insensitive match of a listed word, or of a short word
    /// spelled out letter by letter (e.g. "G T M" -> "GTM"), is replaced with the listed spelling.
    public static func applyWordList(_ text: String, words: [String]) -> String {
        var s = text
        for w in words where !w.isEmpty {
            let spaced = w.count <= 5 && !w.contains(" ") ? w.map(String.init).joined(separator: " ") : nil
            for variant in [w, spaced].compactMap({ $0 }) {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: variant) + "\\b"
                if let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    s = re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s),
                                                    withTemplate: NSRegularExpression.escapedTemplate(for: w))
                }
            }
        }
        return s
    }

    /// Words, ignoring list numbers and bullets.
    public static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace }).filter { tok in
            let t = tok.trimmingCharacters(in: .punctuationCharacters)
            return !t.isEmpty && Int(t) == nil
        }.count
    }
}

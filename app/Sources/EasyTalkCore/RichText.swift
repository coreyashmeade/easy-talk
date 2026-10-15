import AppKit

/// Turns the cleaned Markdown-ish text ("- " bullets, "1. " numbers, blank-line paragraphs) into
/// HTML and RTF so pasted lists are real lists (PRD R22). Plain text is kept as the fallback.
public enum RichText {
    public static func html(from text: String) -> String {
        var out = "<meta charset=\"utf-8\"><div>"
        for block in text.components(separatedBy: "\n\n") where !block.trimmingCharacters(in: .whitespaces).isEmpty {
            var para: [String] = []
            var listTag: String?
            var items: [String] = []
            func flushPara() {
                if !para.isEmpty { out += "<p>" + para.joined(separator: "<br>") + "</p>"; para = [] }
            }
            func flushList() {
                if let tag = listTag { out += "<\(tag)>" + items.map { "<li>\($0)</li>" }.joined() + "</\(tag)>" }
                listTag = nil
                items = []
            }
            for raw in block.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                if line.isEmpty { continue }
                if let r = line.range(of: #"^[-•*]\s+"#, options: .regularExpression) {
                    flushPara(); if listTag != "ul" { flushList(); listTag = "ul" }
                    items.append(escape(String(line[r.upperBound...])))
                } else if let r = line.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                    flushPara(); if listTag != "ol" { flushList(); listTag = "ol" }
                    items.append(escape(String(line[r.upperBound...])))
                } else {
                    flushList(); para.append(escape(line))
                }
            }
            flushPara()
            flushList()
        }
        return out + "</div>"
    }

    public static func rtf(fromHTML html: String) -> Data? {
        guard let data = html.data(using: .utf8),
              let attr = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html,
                                                                       .characterEncoding: String.Encoding.utf8.rawValue],
                                                 documentAttributes: nil)
        else { return nil }
        return try? attr.data(from: NSRange(location: 0, length: attr.length),
                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }
}

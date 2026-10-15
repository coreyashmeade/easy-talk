// M2 rich-paste spike. Puts a sample cleaned dictation on the clipboard the way Easy Talk would
// (HTML + RTF + plain text together) for checking paste results in each target app.
// Usage: swift paste.swift [rich|plain]
import AppKit

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "rich"

// What the cleanup model returns (Markdown-ish plain text).
let plain = """
Quick update on the launch.

Three things for this week:
1. Confirm the venue
2. Send the deck to Priya
3. Book flights for Wednesday

Open questions:
- Pricing page copy
- Waitlist or not

Thanks, Corey
"""

// The same content as simple HTML (what we'd convert to for rich paste).
let html = """
<meta charset="utf-8"><div>
<p>Quick update on the launch.</p>
<p>Three things for this week:</p>
<ol><li>Confirm the venue</li><li>Send the deck to Priya</li><li>Book flights for Wednesday</li></ol>
<p>Open questions:</p>
<ul><li>Pricing page copy</li><li>Waitlist or not</li></ul>
<p>Thanks, Corey</p>
</div>
"""

let pb = NSPasteboard.general
pb.clearContents()
if mode == "plain" {
    pb.setString(plain, forType: .string)
    print("Copied PLAIN text only. Paste with ⌘V.")
} else {
    let htmlData = html.data(using: .utf8)!
    let attr = try NSAttributedString(data: htmlData, options: [.documentType: NSAttributedString.DocumentType.html,
                                                               .characterEncoding: String.Encoding.utf8.rawValue],
                                      documentAttributes: nil)
    let rtf = try attr.data(from: NSRange(location: 0, length: attr.length),
                            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    pb.declareTypes([.html, .rtf, .string], owner: nil)
    pb.setData(htmlData, forType: .html)
    pb.setData(rtf, forType: .rtf)
    pb.setString(plain, forType: .string)
    print("Copied RICH text (HTML + RTF + plain fallback). Paste with ⌘V.")
}

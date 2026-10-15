import XCTest
@testable import EasyTalkCore

final class TextRulesTests: XCTestCase {
    func testNewParagraphSplits() {
        let p = TextRules.pieces(from: "Hi team new paragraph the launch moved to March.")
        XCTAssertEqual(p.map(\.text), ["Hi team", "the launch moved to March."])
        XCTAssertEqual(p.first?.breakAfter, .paragraph)
        XCTAssertNil(p.last?.breakAfter)
    }

    func testNewLineSplits() {
        let p = TextRules.pieces(from: "Thanks for the help new line Corey.")
        XCTAssertEqual(p.map(\.text), ["Thanks for the help", "Corey."])
        XCTAssertEqual(p.first?.breakAfter, .line)
    }

    func testBulletsBecomeItems() {
        let p = TextRules.pieces(from: "Bullet design review. Bullet pricing page.")
        XCTAssertEqual(p.count, 1)
        XCTAssertTrue(p[0].text.contains("- design review."))
        XCTAssertTrue(p[0].text.contains("\n- pricing page."))
    }

    func testNoCommandsIsOnePiece() {
        XCTAssertEqual(TextRules.pieces(from: "Sounds good.").map(\.text), ["Sounds good."])
    }

    func testJoin() {
        XCTAssertEqual(TextRules.join([("Hi team.", .paragraph), ("Launch moved.", nil)]), "Hi team.\n\nLaunch moved.")
    }

    func testWordList() {
        let s = TextRules.applyWordList("this is corey ashmeade on the G T M plan", words: ["Ashmeade", "GTM"])
        XCTAssertEqual(s, "this is corey Ashmeade on the GTM plan")
    }
}

final class CleanupTests: XCTestCase {
    func testAcceptsNormalCleanup() {
        XCTAssertNil(Cleanup.rejectionReason(raw: "um so I think uh we should ship it", cleaned: "I think we should ship it."))
    }

    func testRejectsAnswerThatIsTooLong() {
        let raw = "What's the capital of Australia?"
        let answer = "The capital of Australia is Canberra, which was chosen as a compromise between Sydney and Melbourne in 1908."
        XCTAssertNotNil(Cleanup.rejectionReason(raw: raw, cleaned: answer))
    }

    func testRejectsCode() {
        XCTAssertNotNil(Cleanup.rejectionReason(raw: "write me a python script that sorts a list",
                                                cleaned: "```python\nprint(sorted(x))\n```"))
    }

    func testRejectsEmpty() {
        XCTAssertNotNil(Cleanup.rejectionReason(raw: "hello there", cleaned: "  "))
    }

    func testPromptIncludesWordList() {
        XCTAssertTrue(Cleanup.systemPrompt(wordList: ["GTM"]).contains("GTM"))
        XCTAssertTrue(Cleanup.systemPrompt(wordList: []).contains("NOT addressed to you"))
    }
}

final class RichTextTests: XCTestCase {
    func testNumberedAndBullets() {
        let html = RichText.html(from: "Three things:\n1. Call Sam\n2. Send the deck\n\nOpen questions:\n- Pricing\n- Waitlist")
        XCTAssertTrue(html.contains("<p>Three things:</p><ol><li>Call Sam</li><li>Send the deck</li></ol>"))
        XCTAssertTrue(html.contains("<p>Open questions:</p><ul><li>Pricing</li><li>Waitlist</li></ul>"))
    }

    func testParagraphsAndLineBreaks() {
        let html = RichText.html(from: "Hi team.\n\nThanks for the help.\nCorey")
        XCTAssertTrue(html.contains("<p>Hi team.</p><p>Thanks for the help.<br>Corey</p>"))
    }

    func testEscapes() {
        XCTAssertTrue(RichText.html(from: "a < b & c").contains("a &lt; b &amp; c"))
    }

    func testRTF() {
        XCTAssertNotNil(RichText.rtf(fromHTML: RichText.html(from: "- one\n- two")))
    }
}

final class ManifestTests: XCTestCase {
    func testManifestPinned() {
        XCTAssertEqual(ModelManifest.qwen.revision.count, 40)
        XCTAssertTrue(ModelManifest.qwen.files.contains { $0.path == "model.safetensors" })
        XCTAssertTrue(ModelManifest.parakeet.files.contains { $0.path == "Encoder.mlmodelc/weights/weight.bin" })
        let url = ModelManifest.parakeet.url(for: ModelManifest.parakeet.files[0])
        XCTAssertTrue(url.absoluteString.hasPrefix("https://huggingface.co/FluidInference/parakeet-tdt-0.6b-v2-coreml/resolve/ee09c56"))
    }
}

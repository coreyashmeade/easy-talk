import AppKit
import ApplicationServices
import EasyTalkCore

/// Puts the result where the cursor is (R21-R24). Writes HTML + RTF + plain text together so each app
/// takes the richest form it supports, presses ⌘V, then restores the user's clipboard.
enum Paster {
    enum Outcome { case pasted, copied }

    static func deliver(_ text: String) -> Outcome {
        let pb = NSPasteboard.general
        let target = hasFocusedTextTarget()
        let saved = target ? snapshot(pb) : nil

        let html = RichText.html(from: text)
        pb.clearContents()
        pb.declareTypes([.html, .rtf, .string], owner: nil)
        pb.setData(Data(html.utf8), forType: .html)
        if let rtf = RichText.rtf(fromHTML: html) { pb.setData(rtf, forType: .rtf) }
        pb.setString(text, forType: .string)

        guard target else { return .copied }  // R24: keep it on the clipboard
        let ours = pb.changeCount
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            // Easy Talk's own windows (e.g. the setup practice box): paste straight into the focused field.
            NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
        } else {
            pressCommandV()
        }
        // Restore the previous clipboard once the app has had time to read the paste (R23).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard pb.changeCount == ours, let saved else { return }
            pb.clearContents()
            if !saved.isEmpty { pb.writeObjects(saved) }
        }
        return .pasted
    }

    /// True when the frontmost app has a focused element that accepts text. Reads only the element's role
    /// and whether its value is editable, never its contents (R43).
    static func hasFocusedTextTarget() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let el = focused else { return false }
        let element = el as! AXUIElement
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        if ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXWebArea"].contains(role) { return true }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        return settable.boolValue
    }

    private static func snapshot(_ pb: NSPasteboard) -> [NSPasteboardItem] {
        (pb.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
    }

    private static func pressCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

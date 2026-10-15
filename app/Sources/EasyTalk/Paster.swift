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
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        // Electron and Chromium apps (Claude, Slack, VS Code…) only expose their text fields to
        // accessibility clients after this flag is set.
        AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)

        var focused: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused)
        if result != .success || focused == nil {
            let sys = AXUIElementCreateSystemWide()
            result = AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused)
        }
        let appName = app.bundleIdentifier ?? app.localizedName ?? "unknown"
        guard result == .success, let el = focused else {
            // No focused element reported. A frontmost app with a key window almost always has a text cursor
            // when someone dictates, so paste; the Finder desktop and similar have no window.
            let hasWindow = windowCount(appElement) > 0 && app.bundleIdentifier != "com.apple.finder"
            Log.write("Paste target: \(appName), no focused element reported, window=\(hasWindow)")
            return hasWindow
        }
        let element = el as! AXUIElement
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef)
        let role = roleRef as? String ?? ""
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        let textRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXWebArea"]
        let accepts = textRoles.contains(role) || settable.boolValue
        Log.write("Paste target: \(appName), role=\(role.isEmpty ? "none" : role), editable=\(settable.boolValue), paste=\(accepts)")
        return accepts
    }

    private static func windowCount(_ app: AXUIElement) -> Int {
        var windows: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows) == .success else { return 0 }
        return (windows as? [AXUIElement])?.count ?? 0
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

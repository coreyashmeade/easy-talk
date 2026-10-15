// M2 hotkey spike: catch Control + Option + Space system-wide, swallow it, support hold-to-talk,
// double-tap lock and Esc cancel, and show a test pill at the bottom middle of the active display.
// Prototype; not shipped. No audio is recorded.
import AppKit
import ApplicationServices

let spaceKey: Int64 = 49
let escKey: Int64 = 53
let minHold: TimeInterval = 0.3
let doubleTapWindow: TimeInterval = 0.4

enum Mode { case idle, holding, locked }

final class Spike: NSObject, NSApplicationDelegate {
    var mode: Mode = .idle
    var pressStart = Date.distantPast
    var lastTapEnd = Date.distantPast
    var swallowedCount = 0
    var window: NSWindow!
    var label: NSTextField!
    var tap: CFMachPort?
    var log: FileHandle?

    func applicationDidFinishLaunching(_ n: Notification) {
        let logURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/EasyTalkHotkeySpike.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        log = try? FileHandle(forWritingTo: logURL)
        makePill()
        let trusted = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        say("Started. Accessibility trusted: \(trusted)")
        if !trusted { show("Grant Accessibility, then relaunch", for: 6) }
        installTap()
    }

    func say(_ s: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(s)\n"
        print(line, terminator: "")
        log?.write(line.data(using: .utf8)!)
    }

    // MARK: pill
    func makePill() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 260, height: 44), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let v = NSView(frame: window.contentView!.bounds)
        v.wantsLayer = true
        v.layer?.cornerRadius = 22
        v.layer?.backgroundColor = NSColor(red: 1, green: 0.82, blue: 0.25, alpha: 0.86).cgColor
        label = NSTextField(labelWithString: "")
        label.drawsBackground = false
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = NSColor(red: 0.165, green: 0.129, blue: 0.094, alpha: 1)
        label.alignment = .center
        label.frame = NSRect(x: 12, y: 12, width: 236, height: 20)
        v.addSubview(label)
        window.contentView = v
    }

    /// The display the user is working on: the screen holding the focused window, else the mouse.
    func activeScreen() -> NSScreen {
        let sys = AXUIElementCreateSystemWide()
        var app: CFTypeRef?
        if AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &app) == .success, let app {
            var win: CFTypeRef?
            if AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &win) == .success, let win {
                var posV: CFTypeRef?, sizeV: CFTypeRef?
                AXUIElementCopyAttributeValue(win as! AXUIElement, kAXPositionAttribute as CFString, &posV)
                AXUIElementCopyAttributeValue(win as! AXUIElement, kAXSizeAttribute as CFString, &sizeV)
                var p = CGPoint.zero, s = CGSize.zero
                if let posV { AXValueGetValue(posV as! AXValue, .cgPoint, &p) }
                if let sizeV { AXValueGetValue(sizeV as! AXValue, .cgSize, &s) }
                let center = CGPoint(x: p.x + s.width / 2, y: p.y + s.height / 2)  // top-left origin coords
                let primaryH = NSScreen.screens.first?.frame.height ?? 0
                let flipped = CGPoint(x: center.x, y: primaryH - center.y)
                if let scr = NSScreen.screens.first(where: { $0.frame.contains(flipped) }) { return scr }
            }
        }
        let m = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(m) }) ?? NSScreen.main!
    }

    func show(_ text: String, for seconds: Double? = nil) {
        DispatchQueue.main.async {
            self.label.stringValue = text
            let scr = self.activeScreen()
            let vf = scr.visibleFrame  // excludes the Dock
            self.window.setFrameOrigin(NSPoint(x: vf.midX - 130, y: vf.minY + 14))
            self.window.orderFrontRegardless()
            if let seconds {
                DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { if self.mode == .idle { self.window.orderOut(nil) } }
            }
        }
    }

    // MARK: event tap
    func installTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let cb: CGEventTapCallBack = { _, type, event, refcon in
            let me = Unmanaged<Spike>.fromOpaque(refcon!).takeUnretainedValue()
            return me.handle(type: type, event: event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: CGEventMask(mask), callback: cb,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { say("Could not create event tap (Accessibility not granted?)"); return }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        say("Event tap installed")
    }

    func isTrigger(_ e: CGEvent) -> Bool {
        let f = e.flags
        return e.getIntegerValueField(.keyboardEventKeycode) == spaceKey
            && f.contains(.maskControl) && f.contains(.maskAlternate)
            && !f.contains(.maskCommand) && !f.contains(.maskShift)
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            say("Tap re-enabled after \(type == .tapDisabledByTimeout ? "timeout" : "user input")")
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        if type == .keyDown && key == escKey && mode != .idle {
            mode = .idle
            say("CANCEL (Esc)")
            show("Cancelled", for: 1)
            return nil
        }
        // While a trigger is active, swallow every space key event (down, repeat, up), whatever modifiers remain.
        if key == spaceKey && (mode != .idle || isTrigger(event)) {
            swallowedCount += 1
            if type == .keyDown && !isRepeat { triggerDown() }
            if type == .keyUp { triggerUp() }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }

    func triggerDown() {
        let now = Date()
        switch mode {
        case .idle:
            if now.timeIntervalSince(lastTapEnd) < doubleTapWindow {
                mode = .locked
                say("LOCKED (double-tap)")
                show("Locked · press ⌃⌥Space to finish")
            } else {
                mode = .holding
                pressStart = now
                say("HOLD start")
                show("Listening…")
            }
        case .locked:
            mode = .idle
            say("LOCKED end -> would paste")
            show("Done (locked)", for: 1)
        case .holding:
            break
        }
    }

    func triggerUp() {
        guard mode == .holding else { return }
        let held = Date().timeIntervalSince(pressStart)
        mode = .idle
        if held < minHold {
            lastTapEnd = Date()
            say(String(format: "TAP %.2fs (ignored; double-tap within 0.4s to lock)", held))
            window.orderOut(nil)
        } else {
            say(String(format: "HOLD end %.2fs -> would paste. Spaces swallowed so far: %d", held, swallowedCount))
            show(String(format: "Done · held %.1fs", held), for: 1)
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let spike = Spike()
app.delegate = spike
app.run()

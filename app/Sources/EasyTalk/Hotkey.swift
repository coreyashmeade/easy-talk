import AppKit
import ApplicationServices

/// System-wide Control + Option + Space using a keyboard event tap (needs Accessibility).
/// The trigger keystrokes are swallowed so no stray space is typed (R2). Proven in the M2 hotkey spike.
final class Hotkey {
    enum Event { case pressStart, pressEnd(held: TimeInterval), escape }

    var onEvent: ((Event) -> Void)?
    /// When true, Esc is swallowed and reported (only while recording or processing).
    var escapeActive = false

    private var tap: CFMachPort?
    private var down = false
    private var pressStart = Date()
    private let spaceKey: Int64 = 49
    private let escKey: Int64 = 53

    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    func install() -> Bool {
        guard tap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        let cb: CGEventTapCallBack = { _, type, event, refcon in
            Unmanaged<Hotkey>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event)
        }
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: CGEventMask(mask), callback: cb,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    private func isTrigger(_ e: CGEvent) -> Bool {
        let f = e.flags
        return e.getIntegerValueField(.keyboardEventKeycode) == spaceKey
            && f.contains(.maskControl) && f.contains(.maskAlternate) && !f.contains(.maskCommand) && !f.contains(.maskShift)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyDown && key == escKey && escapeActive {
            DispatchQueue.main.async { self.onEvent?(.escape) }
            return nil
        }
        if key == spaceKey && (down || isTrigger(event)) {
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            if type == .keyDown && !isRepeat && !down {
                down = true
                pressStart = Date()
                DispatchQueue.main.async { self.onEvent?(.pressStart) }
            } else if type == .keyUp && down {
                down = false
                let held = Date().timeIntervalSince(pressStart)
                DispatchQueue.main.async { self.onEvent?(.pressEnd(held: held)) }
            }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}

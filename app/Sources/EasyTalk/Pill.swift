import AppKit
import SwiftUI

// Approved design (docs/design/Main.dc.html): warm yellow, slightly see-through pill with cat ears and a
// zig-zag mark, at the lower middle of the active display just above the Dock (R26).
enum Brand {
    static let ink = Color(red: 0.165, green: 0.129, blue: 0.094)         // #2A2118
    static let pill = Color(red: 1.0, green: 0.824, blue: 0.247)          // #FFD23F
    static let pillMuted = Color(red: 0.42, green: 0.325, blue: 0.09)     // #6B5317
    static let red = Color(red: 0.784, green: 0.196, blue: 0.118)         // #C8321E
    static let warning = Color(red: 0.541, green: 0.227, blue: 0.063)     // #8A3A10
    static let stripes = Color(red: 0.361, green: 0.263, blue: 0.09)      // #5C4317
    static let surface = Color(red: 1.0, green: 0.984, blue: 0.937)       // #FFFBEF
    static let button = Color(red: 0.961, green: 0.773, blue: 0.094)      // #F5C518
    static let accentStrong = Color(red: 0.698, green: 0.227, blue: 0.133) // #B23A22
}

enum PillState: Equatable {
    case listening(seconds: Int, level: Double)
    case locked(seconds: Int, level: Double)
    case warning(secondsLeft: Int)
    case thinking
    case done(words: Int)
    case copied
    case cancelled
    case noSpeech
    case fallback(String)
    case problem(String)
}

final class PillModel: ObservableObject {
    @Published var state: PillState = .thinking
}

struct EarShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.26, y: r.minY + r.height * 0.17))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.46, y: r.minY + r.height * 0.1),
                       control: CGPoint(x: r.minX + r.width * 0.32, y: r.minY - r.height * 0.04))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct ZigZagMark: View {
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 22, sy = size.height / 18
            var p = Path()
            for o in [0.0, 6.5, 13.0] {
                p.move(to: CGPoint(x: (2 + o) * sx, y: 16 * sy))
                p.addLine(to: CGPoint(x: (5.5 + o) * sx, y: 9.5 * sy))
                p.addLine(to: CGPoint(x: (3.5 + o) * sx, y: 8.5 * sy))
                p.addLine(to: CGPoint(x: (7 + o) * sx, y: 2 * sy))
            }
            ctx.stroke(p, with: .color(Brand.stripes.opacity(0.55)), style: StrokeStyle(lineWidth: 2.1, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 22, height: 18)
        .accessibilityHidden(true)
    }
}

struct SoundBars: View {
    let level: Double
    let color: Color
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array([0.4, 0.8, 1.0, 0.6, 0.3].enumerated()), id: \.offset) { _, base in
                Capsule().fill(color).frame(width: 3, height: max(4, 20 * base * (0.35 + 0.65 * level)))
                    .shadow(color: Brand.ink.opacity(0.9), radius: 0.6)
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.12), value: level)
    }
}

struct PillView: View {
    @ObservedObject var model: PillModel

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 10) {
                leading
                Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Brand.ink)
                Spacer(minLength: 8)
                if let detail { Text(detail).font(.system(size: 14).monospacedDigit()).foregroundStyle(detailColor) }
                ZigZagMark()
            }
            .padding(.horizontal, 16)
            .frame(width: 300, height: 44)
            .background(
                ZStack {
                    VisualEffect().clipShape(Capsule())
                    Capsule().fill(Brand.pill.opacity(0.86))
                }
            )
            .padding(.top, 13)
            HStack {
                EarShape().fill(Brand.pill.opacity(0.86)).frame(width: 18, height: 14)
                Spacer()
                EarShape().fill(Brand.pill.opacity(0.86)).frame(width: 18, height: 14).scaleEffect(x: -1)
            }
            .padding(.horizontal, 26)
        }
        .frame(width: 300, height: 57)
    }

    @ViewBuilder private var leading: some View {
        switch model.state {
        case .listening(_, let level): SoundBars(level: level, color: Brand.red)
        case .locked: icon("lock.fill", Brand.red)
        case .warning: SoundBars(level: 0.6, color: Brand.warning)
        case .thinking: ThinkingDots()
        case .done: icon("checkmark", Brand.red)
        case .copied: icon("doc.on.doc", Brand.ink)
        case .cancelled: icon("xmark", Brand.pillMuted)
        case .noSpeech: icon("mic.slash", Brand.pillMuted)
        case .fallback, .problem: icon("exclamationmark.triangle.fill", Brand.warning)
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            .shadow(color: Brand.ink.opacity(0.9), radius: 0.6)
            .frame(width: 20)
    }

    private var label: String {
        switch model.state {
        case .listening: return "Listening"
        case .locked: return "Locked"
        case .warning: return "30 seconds left"
        case .thinking: return "Cleaning up"
        case .done: return "Pasted"
        case .copied: return "Copied to clipboard"
        case .cancelled: return "Cancelled"
        case .noSpeech: return "Didn't catch that"
        case .fallback: return "Pasted raw text"
        case .problem(let m): return m
        }
    }

    private var detail: String? {
        switch model.state {
        case .listening(let s, _): return clock(s)
        case .locked(let s, _): return "⌃⌥Space ends · \(clock(s))"
        case .warning(let left): return clock(300 - left)
        case .thinking: return "Esc to cancel"
        case .done(let w): return "\(w) words"
        case .copied: return "⌘V"
        case .cancelled: return "Nothing pasted"
        case .fallback(let why): return why
        default: return nil
        }
    }

    private var detailColor: Color {
        if case .warning = model.state { return Brand.warning }
        return Brand.pillMuted
    }

    private func clock(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
}

struct ThinkingDots: View {
    @State private var phase = 0
    let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle().fill(i == phase ? Brand.ink : Brand.pillMuted.opacity(0.6)).frame(width: 6, height: 6)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

/// Borderless, click-through panel that hosts the pill on the active display.
final class PillController {
    let model = PillModel()
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 57), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: PillView(model: model))
    }

    func show(_ state: PillState, hideAfter: Double? = nil) {
        hideWork?.cancel()
        model.state = state
        if !panel.isVisible {
            let vf = ActiveDisplay.screen().visibleFrame  // visibleFrame excludes the Dock
            panel.setFrameOrigin(NSPoint(x: vf.midX - 150, y: vf.minY + 14))
            panel.orderFrontRegardless()
        }
        if let hideAfter {
            let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + hideAfter, execute: work)
        }
    }

    func hide() { hideWork?.cancel(); panel.orderOut(nil) }
}

/// The display the user is working on: the screen holding the focused window (position only), else the mouse.
enum ActiveDisplay {
    static func screen() -> NSScreen {
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
                let primaryH = NSScreen.screens.first?.frame.height ?? 0
                let center = CGPoint(x: p.x + s.width / 2, y: primaryH - (p.y + s.height / 2))
                if let scr = NSScreen.screens.first(where: { $0.frame.contains(center) }) { return scr }
            }
        }
        let m = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(m) }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

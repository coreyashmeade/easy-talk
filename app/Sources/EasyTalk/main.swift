import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon (R25)
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()

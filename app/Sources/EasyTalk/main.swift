import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "--selftest" {
    Task {
        let code = await SelfTest.run(arguments: Array(arguments.dropFirst()))
        exit(code)
    }
    RunLoop.main.run()
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)  // menu bar only, no Dock icon (R25)
    let appDelegate = AppDelegate()
    app.delegate = appDelegate
    app.run()
}

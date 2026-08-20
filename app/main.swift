import Cocoa

// NoSleep — menu bar toggle for `pmset disablesleep` + `caffeinate`,
// mirroring the `nosleep` shell helper in ~/.zshrc.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let stateFile = "/tmp/.nosleep_active"
    private var statusItem: NSStatusItem!
    private var contextMenu: NSMenu!
    private var statusLabel: NSMenuItem!
    private var caffeinate: Process?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Named so macOS persists its slot; without this it can land in the
        // notch dead zone on a crowded menu bar and be invisible/unclickable.
        statusItem.autosaveName = "NoSleepStatusItem"

        // Left click toggles directly. The menu is only assigned on a right/ctrl
        // click -- assigning it permanently would swallow the left click.
        contextMenu = NSMenu()
        contextMenu.delegate = self
        statusLabel = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLabel.isEnabled = false
        contextMenu.addItem(statusLabel)
        contextMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NoSleep", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        contextMenu.addItem(quit)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Adopt whatever state the machine is already in (e.g. set from the shell
        // helper) rather than forcing a state and risking an unexpected sleep.
        if isSleepDisabled() {
            writeStateFile(true)
            startCaffeinate()   // always own the assertion, so status is unambiguous
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Quitting kills our caffeinate no matter what, so drop the pmset half
        // too -- otherwise sleep stays disabled with no icon left to undo it.
        stopCaffeinate()
        if isSleepDisabled() {
            _ = setSleepDisabled(false)
            writeStateFile(false)
        }
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    // MARK: - Actions

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            statusItem.menu = contextMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil   // hand the left click back to us
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        let turningOn = !isSleepDisabled()

        if turningOn {
            guard setSleepDisabled(true) else { return }
            if caffeinate == nil { startCaffeinate() }
            writeStateFile(true)
        } else {
            stopCaffeinate()
            guard setSleepDisabled(false) else { return }
            writeStateFile(false)
        }
        refresh()
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - UI

    private func refresh() {
        let on = isSleepDisabled()
        let symbol = on ? "cup.and.saucer.fill" : "cup.and.saucer"
        let description = on ? "Sleep disabled" : "Sleep enabled"
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
            image?.isTemplate = true
            button.image = image
            button.toolTip = on ? "NoSleep: ON — sleep disabled" : "NoSleep: OFF — sleep enabled"
        }
        statusLabel?.title = on ? "Keep Awake: ON" : "Keep Awake: OFF"
    }

    private func warn(_ message: String, _ detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }

    // MARK: - pmset

    private func isSleepDisabled() -> Bool {
        let out = run("/usr/bin/pmset", ["-g"]).stdout
        guard let line = out.split(separator: "\n").first(where: { $0.contains("SleepDisabled") })
        else { return false }
        return line.contains("1")
    }

    /// Needs the passwordless rule in /etc/sudoers.d/nosleep; -n so we never
    /// hang on an invisible password prompt from a GUI app.
    private func setSleepDisabled(_ disabled: Bool) -> Bool {
        let result = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "disablesleep", disabled ? "1" : "0"])
        if result.status != 0 {
            warn("Couldn't change the sleep setting",
                 "`sudo -n pmset disablesleep` failed (exit \(result.status)).\n\n\(result.stderr)")
            return false
        }
        return true
    }

    // MARK: - caffeinate

    private func startCaffeinate() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.terminationHandler = { [weak self] finished in
            DispatchQueue.main.async {
                guard let self, self.caffeinate == finished else { return }
                self.caffeinate = nil
                self.refresh()
            }
        }
        do {
            try process.run()
            caffeinate = process
        } catch {
            warn("Couldn't start caffeinate", error.localizedDescription)
        }
    }

    private func stopCaffeinate() {
        caffeinate?.terminate()
        caffeinate = nil
    }

    // MARK: - State file (keeps the shell helper in sync)

    private func writeStateFile(_ active: Bool) {
        if active {
            FileManager.default.createFile(atPath: stateFile, contents: Data())
        } else {
            try? FileManager.default.removeItem(atPath: stateFile)
        }
    }

    // MARK: - Shell

    private func run(_ path: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do { try process.run() } catch { return (-1, "", error.localizedDescription) }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self))
    }
}

private extension FileManager {
    func createFile(atPath path: String, contents: Data) {
        createFile(atPath: path, contents: contents, attributes: nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

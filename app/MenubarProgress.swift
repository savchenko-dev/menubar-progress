import AppKit

struct Item: Decodable {
    let id: String
    var title: String?
    var group: String?
    var icon: String?
    var state: String?
    var done: Double?
    var total: Double?
    var text: String?
    var open: String?
    var updated: Double?
    var ttl: Double?

    var isFinished: Bool { state == "ok" || state == "fail" }

    var isExpired: Bool {
        guard isFinished, let ttl, let updated else { return false }
        return Date().timeIntervalSince1970 - updated > ttl
    }

    var fraction: Double? {
        guard let done, let total, total > 0 else { return nil }
        return min(max(done / total, 0), 1)
    }

    var isStale: Bool {
        guard state == "running", let updated else { return false }
        return Date().timeIntervalSince1970 - updated > 600
    }
}

let stateDir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["MBP_DIR"]
    ?? NSHomeDirectory() + "/.local/state/mbp")

func loadItems() -> [Item] {
    let files = (try? FileManager.default.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: nil)) ?? []
    var items: [Item] = []
    for file in files where file.pathExtension == "json" {
        guard let item = try? JSONDecoder().decode(Item.self, from: Data(contentsOf: file)) else { continue }
        if item.isExpired {
            try? FileManager.default.removeItem(at: file)
        } else {
            items.append(item)
        }
    }
    return items.sorted { ($0.group ?? "", $0.id) < ($1.group ?? "", $1.id) }
}

func bar(_ fraction: Double, width: Int = 12) -> String {
    let filled = Int((fraction * Double(width)).rounded())
    return String(repeating: "▓", count: filled) + String(repeating: "░", count: width - filled)
}

func badge(_ item: Item) -> String {
    if item.isStale { return "⏸" }
    switch item.state {
    case "ok": return "✅"
    case "fail": return "❌"
    case "wait": return "⏳"
    default: return "▶︎"
    }
}

final class Controller: NSObject {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?

    func start() {
        statusItem.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        refresh()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        let items = loadItems()
        statusItem.button?.title = title(for: items)
        statusItem.menu = menu(for: items)
    }

    func title(for items: [Item]) -> String {
        if items.isEmpty { return "◌" }
        var parts: [String] = []
        for (group, members) in Dictionary(grouping: items, by: { $0.group ?? "" }).sorted(by: { $0.key < $1.key }) {
            let icon = members.first(where: { $0.icon != nil })?.icon ?? (group.isEmpty ? "●" : String(group.prefix(1)))
            let finished = members.filter { $0.state == "ok" }.count
            let failed = members.contains { $0.state == "fail" } ? "❌" : ""
            let running = members.filter { $0.state == "running" || $0.state == nil }
            let fractions = running.compactMap(\.fraction)
            let percent = fractions.isEmpty ? "" : " \(Int(fractions.reduce(0, +) / Double(fractions.count) * 100))%"
            parts.append("\(icon)\(finished)/\(members.count)\(percent)\(failed)")
        }
        return parts.joined(separator: "  ")
    }

    func menu(for items: [Item]) -> NSMenu {
        let menu = NSMenu()
        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        var lastGroup: String?
        for item in items {
            let group = item.group ?? ""
            if group != lastGroup {
                if lastGroup != nil { menu.addItem(.separator()) }
                if !group.isEmpty {
                    let header = NSMenuItem(title: "\(item.icon ?? "") \(group)", action: nil, keyEquivalent: "")
                    header.isEnabled = false
                    menu.addItem(header)
                }
                lastGroup = group
            }
            var line = "\(badge(item)) \((item.title ?? item.id).padding(toLength: 12, withPad: " ", startingAt: 0))"
            if let fraction = item.fraction, !item.isFinished {
                line += " \(bar(fraction)) \(String(format: "%3d%%", Int(fraction * 100)))"
            }
            if let text = item.text, !text.isEmpty { line += "  \(text)" }
            let entry = NSMenuItem(title: line, action: #selector(openPath(_:)), keyEquivalent: "")
            entry.attributedTitle = NSAttributedString(string: line, attributes: [.font: font])
            entry.target = self
            entry.representedObject = item.open
            entry.isEnabled = item.open != nil
            menu.addItem(entry)
        }
        if items.isEmpty {
            let empty = NSMenuItem(title: "No tasks in \(stateDir.path)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear finished", action: #selector(clearFinished), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc func openPath(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc func clearFinished() {
        let files = (try? FileManager.default.contentsOfDirectory(at: stateDir, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "json" {
            if let item = try? JSONDecoder().decode(Item.self, from: Data(contentsOf: file)), item.isFinished {
                try? FileManager.default.removeItem(at: file)
            }
        }
        refresh()
    }
}

try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "menu bar progress refresh")
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let controller = Controller()
controller.start()
app.run()

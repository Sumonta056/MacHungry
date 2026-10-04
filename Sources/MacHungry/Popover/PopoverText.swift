enum PopoverText {
    static let cpu = "CPU"
    static let ram = "RAM"
    static let temperature = "Temp"
    static let limited = "limited"
    static let limitedHelp = "/bin/ps failed. The list shows only your own processes."
    static let measuring = "Measuring…"
    static let noActivity = "No activity"
    static let animation = "Animation"
    static let show = "Show"
    static let launchAtLogin = "Launch at login"
    static let quitApp = "Quit MacHungry"
    static let quitIcon = "xmark.circle.fill"

    static func topAppsHeading(limit: Int) -> String {
        "Top \(limit) apps · % of total CPU"
    }

    static func quitHelp(name: String) -> String {
        "Quit \(name)"
    }
}

public enum UsageFormatter {
    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    public static func tooltip(cpu: Double?, memory: Double?) -> String {
        "CPU \(percent(cpu)) · RAM \(percent(memory))"
    }

    public static func memoryDetail(usedBytes: UInt64, totalBytes: UInt64) -> String {
        let gigabyte = 1_073_741_824.0
        let used = (Double(usedBytes) / gigabyte * 10).rounded() / 10
        let total = (Double(totalBytes) / gigabyte).rounded()
        return "\(used) / \(Int(total)) GB"
    }
}

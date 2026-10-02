public enum UsageFormatter {
    public static func percent(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))%"
    }

    public static func tooltip(cpu: Double?, memory: Double?, temperature: Double? = nil) -> String {
        let base = "CPU \(percent(cpu)) · RAM \(percent(memory))"
        guard let temperature, temperature.isFinite else { return base }
        return base + " · \(Int(temperature.rounded()))°C"
    }

    public static func temperature(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "--" }
        return "\(Int(value.rounded()))°"
    }

    public static func temperatureDetail(_ reading: TemperatureReading) -> String {
        [("CPU", reading.cpu), ("GPU", reading.gpu)]
            .compactMap { label, value in
                guard let value, value.isFinite else { return nil }
                return "\(label) \(Int(value.rounded()))°C"
            }
            .joined(separator: "  ")
    }

    public static func memoryDetail(usedBytes: UInt64, totalBytes: UInt64) -> String {
        let gigabyte = 1_073_741_824.0
        let used = (Double(usedBytes) / gigabyte * 10).rounded() / 10
        let total = (Double(totalBytes) / gigabyte).rounded()
        return "\(used) / \(Int(total)) GB"
    }
}

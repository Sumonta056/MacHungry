public enum PSParser {
    public static func parse(_ output: String) -> [ProcessSample] {
        output.split(whereSeparator: \.isNewline).compactMap { parseLine($0) }
    }

    public static func parseLine(_ line: Substring) -> ProcessSample? {
        let afterLeadingSpace = line.drop(while: \.isWhitespace)
        guard let pidEnd = afterLeadingSpace.firstIndex(where: \.isWhitespace),
              let pid = Int32(afterLeadingSpace[..<pidEnd]) else { return nil }
        let afterPid = afterLeadingSpace[pidEnd...].drop(while: \.isWhitespace)
        guard let timeEnd = afterPid.firstIndex(where: \.isWhitespace),
              let seconds = parseTime(afterPid[..<timeEnd]) else { return nil }
        let path = afterPid[timeEnd...].drop(while: \.isWhitespace)
        guard !path.isEmpty else { return nil }
        return ProcessSample(pid: pid, cpuSeconds: seconds, path: String(path))
    }

    public static func parseTime(_ text: Substring) -> Double? {
        var days = 0.0
        var clock = text
        if let dash = text.firstIndex(of: "-") {
            guard let parsedDays = Double(text[..<dash]) else { return nil }
            days = parsedDays
            clock = text[text.index(after: dash)...]
        }
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        let values = parts.compactMap { Double($0) }
        guard (2...3).contains(parts.count), values.count == parts.count,
              values.allSatisfy({ $0.isFinite && $0 >= 0 }), days.isFinite, days >= 0 else { return nil }
        return days * 86_400 + values.reduce(0) { $0 * 60 + $1 }
    }
}

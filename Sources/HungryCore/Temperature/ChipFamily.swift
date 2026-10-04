public enum ChipFamily: Int, Sendable, CaseIterable {
    case m1 = 1
    case m2 = 2
    case m3 = 3
    case m4 = 4

    public static func detect(brand: String) -> ChipFamily? {
        let lower = brand.lowercased()
        let prefix = "apple m"
        guard lower.hasPrefix(prefix) else { return nil }
        let digits = lower.dropFirst(prefix.count).prefix(while: \.isNumber)
        guard let generation = Int(digits) else { return nil }
        return ChipFamily(rawValue: generation)
    }
}

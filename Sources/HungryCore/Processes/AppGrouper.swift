public struct AppIdentity: Hashable, Sendable {
    public var name: String
    public var bundlePath: String?

    public init(name: String, bundlePath: String?) {
        self.name = name
        self.bundlePath = bundlePath
    }
}

public struct AppUsage: Equatable, Sendable, Identifiable {
    public var identity: AppIdentity
    public var percent: Double

    public init(identity: AppIdentity, percent: Double) {
        self.identity = identity
        self.percent = percent
    }

    public var id: String { identity.bundlePath ?? identity.name }
}

public enum AppGrouper {
    public static func identity(forPath path: String) -> AppIdentity {
        let components = path.split(separator: "/")
        if path.hasPrefix("/"), let index = components.firstIndex(where: { $0.hasSuffix(".app") && $0.count > 4 }) {
            let bundlePath = "/" + components[...index].joined(separator: "/")
            return AppIdentity(name: String(components[index].dropLast(4)), bundlePath: bundlePath)
        }
        return AppIdentity(name: components.last.map(String.init) ?? path, bundlePath: nil)
    }

    public static func topApps(_ usages: [ProcessUsage], limit: Int) -> [AppUsage] {
        var totals: [AppIdentity: Double] = [:]
        for usage in usages {
            totals[identity(forPath: usage.path), default: 0] += usage.percent
        }
        let sorted = totals
            .map { AppUsage(identity: $0.key, percent: $0.value) }
            .sorted { $0.percent != $1.percent ? $0.percent > $1.percent : $0.identity.name < $1.identity.name }
        return Array(sorted.prefix(max(limit, 0)))
    }
}

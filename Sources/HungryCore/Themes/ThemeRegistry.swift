public enum ThemeRegistry {
    public static let all: [any AnimationTheme] = [CatTheme(), PushUpTheme(), PullUpTheme()]

    public static var fallback: any AnimationTheme { CatTheme() }

    public static func theme(withID id: String?) -> any AnimationTheme {
        all.first { $0.id == id } ?? fallback
    }
}

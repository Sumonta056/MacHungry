import HungryCore

@MainActor
final class QuitCache {
    private var answers: [String: Bool] = [:]

    func canQuit(_ app: AppUsage) -> Bool {
        guard let path = app.identity.bundlePath else { return false }
        if let cached = answers[path] { return cached }
        let answer = AppTerminator.canQuit(app)
        answers[path] = answer
        return answer
    }
}

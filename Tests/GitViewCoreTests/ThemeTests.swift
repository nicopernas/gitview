import Foundation
import Testing
@testable import GitViewCore

@Suite struct ThemeTests {
    private func defaults() -> UserDefaults {
        let name = "gitview-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsToSystem() {
        #expect(Theme.load(from: defaults()) == .system)
    }

    @Test func savesAndLoads() {
        let d = defaults()
        Theme.light.save(to: d)
        #expect(Theme.load(from: d) == .light)
        Theme.dark.save(to: d)
        #expect(Theme.load(from: d) == .dark)
    }

    @Test func unknownValueFallsBackToSystem() {
        let d = defaults()
        d.set("purple", forKey: "theme")
        #expect(Theme.load(from: d) == .system)
    }
}

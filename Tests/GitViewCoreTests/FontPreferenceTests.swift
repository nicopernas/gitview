import Foundation
import Testing
@testable import GitViewCore

@Suite struct FontPreferenceTests {
    private func defaults() -> UserDefaults {
        let name = "gitview-test-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultsToSourceCodePro() {
        #expect(FontPreference.load(from: defaults()) == FontPreference(name: "SourceCodeProRoman-Regular", size: 12))
    }

    @Test func savesAndLoads() {
        let d = defaults()
        FontPreference(name: "Menlo-Regular", size: 14).save(to: d)
        #expect(FontPreference.load(from: d) == FontPreference(name: "Menlo-Regular", size: 14))
    }

    @Test func clampsSize() {
        let d = defaults()
        FontPreference(name: "Menlo-Regular", size: 2).save(to: d)
        #expect(FontPreference.load(from: d).size == 8)
        FontPreference(name: "Menlo-Regular", size: 100).save(to: d)
        #expect(FontPreference.load(from: d).size == 36)
    }
}

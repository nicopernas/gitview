import Foundation

/// Light, dark, or follow the system. Saved in user defaults.
public enum Theme: String, CaseIterable, Sendable {
    case system, light, dark

    public static func load(from d: UserDefaults = .standard) -> Theme {
        Theme(rawValue: d.string(forKey: "theme") ?? "") ?? .system
    }

    public func save(to d: UserDefaults = .standard) {
        d.set(rawValue, forKey: "theme")
    }
}

import Foundation

/// The font used for the whole window, saved in user defaults.
public struct FontPreference: Equatable, Sendable {
    public var name: String
    public var size: Double

    public init(name: String, size: Double) {
        self.name = name
        self.size = size
    }

    public static let standard = FontPreference(name: "SourceCodeProRoman-Regular", size: 12)
    static let sizes = 8.0...36.0

    public static func load(from d: UserDefaults = .standard) -> FontPreference {
        let name = d.string(forKey: "fontName") ?? standard.name
        let size = d.object(forKey: "fontSize") == nil ? standard.size : d.double(forKey: "fontSize")
        return FontPreference(name: name, size: min(max(size, sizes.lowerBound), sizes.upperBound))
    }

    public func save(to d: UserDefaults = .standard) {
        d.set(name, forKey: "fontName")
        d.set(size, forKey: "fontSize")
    }
}

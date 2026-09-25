import Foundation

public struct Ref: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case branch, remote, tag, other }

    public let name: String
    public let kind: Kind
    /// HEAD points here (current branch, or detached HEAD itself).
    public let isHead: Bool

    public init(name: String, kind: Kind, isHead: Bool) {
        self.name = name
        self.kind = kind
        self.isHead = isHead
    }
}

public struct Commit: Sendable {
    public let hash: String
    public let parents: [String]
    public let author: String
    public let date: Date
    public let subject: String
    public let refs: [Ref]
}

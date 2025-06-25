import Foundation

public struct SensorsRequest: Codable, Sendable {
    public var ids: [Int]

    public init(ids: [Int]) {
        self.ids = ids
    }
}

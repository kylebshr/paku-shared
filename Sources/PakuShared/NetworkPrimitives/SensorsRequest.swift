import Foundation

public struct SensorsRequest: Codable {
    public var ids: [Int]

    public init(ids: [Int]) {
        self.ids = ids
    }
}

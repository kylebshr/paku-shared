import Foundation

public struct PrivateSensorsResponse: Codable, Sendable {
    public var sensors: [PrivateSensorResponse]

    public init(sensors: [PrivateSensorResponse]) {
        self.sensors = sensors
    }
}

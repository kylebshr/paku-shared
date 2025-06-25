import Foundation

public struct SensorsResponse: Codable, Sendable {
    public var sensors: [SensorResponse]

    public init(sensors: [SensorResponse]) {
        self.sensors = sensors
    }
}

import Foundation

public struct SensorsResponse: Codable {
    public var sensors: [SensorResponse]

    public init(sensors: [SensorResponse]) {
        self.sensors = sensors
    }
}

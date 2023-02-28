import Foundation

public struct PrivateSensorsResponse: Codable {
    public var sensors: [PrivateSensorResponse]

    public init(sensors: [PrivateSensorResponse]) {
        self.sensors = sensors
    }
}

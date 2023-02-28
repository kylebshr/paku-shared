import Foundation

public struct PrivateSensorResponse: Codable {
    public var id: UUID
    public var name: String
    public let sensorID: Int
    public let sensorHardwareID: String

    public init(id: UUID, name: String, sensorID: Int, sensorHardwareID: String) {
        self.id = id
        self.name = name
        self.sensorID = sensorID
        self.sensorHardwareID = sensorHardwareID
    }
}

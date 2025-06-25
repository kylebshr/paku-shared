import Foundation

public struct PrivateSensorResponse: Codable, Sendable {
    public var id: UUID
    public var name: String
    public let sensorID: Int
    public let sensorHardwareID: String
    public let latitude: Double
    public let longitude: Double
    public let locationType: LocationType

    public init(id: UUID, name: String, sensorID: Int, sensorHardwareID: String, latitude: Double, longitude: Double, locationType: LocationType) {
        self.id = id
        self.name = name
        self.sensorID = sensorID
        self.sensorHardwareID = sensorHardwareID
        self.latitude = latitude
        self.longitude = longitude
        self.locationType = locationType
    }
}

import Foundation

public struct RegisterPrivateSensorRequest: Codable, Sendable {
    public var userID: UUID
    public var sensorID: String
    public var ownerEmail: String

    public init(userID: UUID, sensorID: String, ownerEmail: String) {
        self.userID = userID
        self.sensorID = sensorID
        self.ownerEmail = ownerEmail
    }
}

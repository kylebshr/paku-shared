import Foundation

public struct PrivateSensorResponse: Codable, Sendable {
    /// How recently a sensor must have reported to count as online. Shared
    /// so the app and server always agree on the threshold.
    public static let onlineThreshold: TimeInterval = 60 * 60

    public var id: UUID
    public var name: String
    public let sensorID: Int
    public let sensorHardwareID: String
    public let latitude: Double
    public let longitude: Double
    public let locationType: LocationType

    /// When the sensor last reported to PurpleAir. nil when the server's
    /// crawl has no data for it at all — a sensor offline long enough falls
    /// out of PurpleAir's group responses entirely (or the server predates
    /// this field).
    public let lastSeen: Date?

    /// Whether PurpleAir lists the sensor on the public map — a public
    /// sensor didn't need private registration. nil when unknown.
    public let isPublic: Bool?

    /// true/false when the sensor has crawl data; nil when it has none
    /// (distinct from offline — the crawl has never seen it).
    public var isOnline: Bool? {
        lastSeen.map { Date().timeIntervalSince($0) < Self.onlineThreshold }
    }

    public init(
        id: UUID,
        name: String,
        sensorID: Int,
        sensorHardwareID: String,
        latitude: Double,
        longitude: Double,
        locationType: LocationType,
        lastSeen: Date? = nil,
        isPublic: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.sensorID = sensorID
        self.sensorHardwareID = sensorHardwareID
        self.latitude = latitude
        self.longitude = longitude
        self.locationType = locationType
        self.lastSeen = lastSeen
        self.isPublic = isPublic
    }
}

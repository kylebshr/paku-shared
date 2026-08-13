import Foundation

/// The payload of every source's directory file (`sensors.json`,
/// `airgradient-sensors.json` — see `SensorSource.directoryFile`) and of
/// `GET /sensors/delta`. One entry per sensor, identity fields only;
/// readings come from the per-ID endpoints.
public struct SensorDirectory: Codable, Sendable, Equatable {
    public struct Entry: Codable, Sendable, Equatable {
        public let id: Int
        public let name: String
        public let loc: LocationType
        public let lat: Double
        public let lon: Double

        public init(id: Int, name: String, loc: LocationType, lat: Double, lon: Double) {
            self.id = id
            self.name = name
            self.loc = loc
            self.lat = lat
            self.lon = lon
        }
    }

    /// Unix timestamp the payload reflects changes up to. Clients store it
    /// and pass it back as `since` to GET /sensors/delta for an incremental
    /// update (PurpleAir only today).
    public let asOf: Int
    public let sensors: [Entry]

    public init(asOf: Int, sensors: [Entry]) {
        self.asOf = asOf
        self.sensors = sensors
    }
}

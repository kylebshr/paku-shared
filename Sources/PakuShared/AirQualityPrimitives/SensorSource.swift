import Foundation

/// Which upstream network a sensor comes from.
///
/// Determined by ID range rather than a wire field: the flat `Int` sensor
/// ID is the key everywhere a sensor is referenced — alerts, history,
/// favorites, deep links, widget configuration, and the `/sensor/:id`
/// routes — so encoding the source in the ID keeps every one of those
/// paths working with no schema or wire-format change, and no way for a
/// stored ID and a stored source to disagree.
public enum SensorSource: String, Codable, Sendable, CaseIterable {
    case purpleAir
    case airGradient

    public var displayName: String {
        switch self {
        case .purpleAir: "PurpleAir"
        case .airGradient: "AirGradient"
        }
    }

    /// The static file serving this source's full sensor directory, as a
    /// `SensorDirectory` payload relative to the API base URL. A client
    /// data-source toggle maps to fetching (or filtering out) one source's
    /// directory; the per-ID endpoints are shared across sources.
    public var directoryFile: String {
        switch self {
        case .purpleAir: "sensors.json"
        case .airGradient: "airgradient-sensors.json"
        }
    }
}

/// The reserved ID ranges that partition the shared sensor ID space, and
/// the conversions between namespaced sensor IDs and each source's native
/// IDs.
///
/// PurpleAir sensor indexes are 6 digits and AirGradient location IDs 7,
/// so a 2e9 offset can't collide with either while staying well inside
/// `Int64` and JavaScript's 2^53. Each future source claims its own
/// offset above the previous one.
///
/// The API contract that rides on this: `sensors.json` and
/// `GET /sensors/delta` remain PurpleAir-only (released clients treat
/// every ID in them as a PurpleAir sensor), and each additional source
/// publishes its own directory file — AirGradient's is
/// `airgradient-sensors.json`, in the same `{asOf, sensors: [...]}` shape.
/// Everything keyed by individual ID (`GET /sensor/:id`,
/// `GET /sensors?ids=`, `GET /sensor/:id/history`, alert registration)
/// is shared: namespaced IDs flow through the same endpoints.
public enum SensorIDSpace {
    public static let airGradientOffset = 2_000_000_000

    public static func source(of sensorID: Int) -> SensorSource {
        sensorID >= airGradientOffset ? .airGradient : .purpleAir
    }

    public static func airGradientSensorID(locationID: Int) -> Int {
        airGradientOffset + locationID
    }

    public static func airGradientLocationID(from sensorID: Int) -> Int? {
        guard sensorID >= airGradientOffset else { return nil }
        return sensorID - airGradientOffset
    }
}

public extension SensorResponse {
    var source: SensorSource {
        SensorIDSpace.source(of: id)
    }
}

public extension Sensor {
    var source: SensorSource {
        SensorIDSpace.source(of: id)
    }
}

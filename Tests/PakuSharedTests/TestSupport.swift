import Foundation
import Testing
@testable import PakuShared

extension SensorResponse {
    /// A sensor response with everything the tests don't care about filled
    /// in. `pm2_5_cf_1` tracks `pm2_5`; the averages stay nil unless a test
    /// sets them.
    static func stub(
        id: Int = 1,
        name: String = "Sensor",
        latitude: Double = 37.0,
        longitude: Double = -122.0,
        locationType: LocationType = .outdoors,
        lastSeen: Date = Date(timeIntervalSince1970: 1_000_000),
        pm2_5: Double? = 10,
        pm2_5_10minute: Double? = nil,
        pm2_5_30minute: Double? = nil,
        pm2_5_60minute: Double? = nil,
        channelFlags: ChannelFlags? = nil
    ) -> SensorResponse {
        SensorResponse(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            locationType: locationType,
            lastSeen: lastSeen,
            pm2_5: pm2_5,
            pm2_5_cf_1: pm2_5,
            pm2_5_10minute: pm2_5_10minute,
            pm2_5_30minute: pm2_5_30minute,
            pm2_5_60minute: pm2_5_60minute,
            channelFlags: channelFlags
        )
    }
}

extension Sensor {
    /// A sensor built from a complete response — `Sensor(response:)` rejects
    /// one whose averages are missing. Each average defaults to `pm2_5`, so
    /// the fast/slow crossover reads flat unless a test sets them apart.
    static func stub(
        id: Int = 1,
        pm2_5: Double = 10,
        pm2_5_10minute: Double? = nil,
        pm2_5_30minute: Double? = nil,
        pm2_5_60minute: Double? = nil,
        channelFlags: ChannelFlags? = nil,
        lastSeen: Date = Date(timeIntervalSince1970: 1_000_000)
    ) throws -> Sensor {
        try Sensor(response: .stub(
            id: id,
            lastSeen: lastSeen,
            pm2_5: pm2_5,
            pm2_5_10minute: pm2_5_10minute ?? pm2_5,
            pm2_5_30minute: pm2_5_30minute ?? pm2_5,
            pm2_5_60minute: pm2_5_60minute ?? pm2_5,
            channelFlags: channelFlags
        ))
    }
}

/// Encodes `value` and strips `key` back out of the JSON — the shape that
/// app versions and servers predating the field produced.
func encoded<T: Encodable>(
    _ value: T,
    omitting key: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> Data {
    let data = try JSONEncoder().encode(value)
    var json = try #require(String(data: data, encoding: .utf8), sourceLocation: sourceLocation)
    json = json.replacingOccurrences(of: "\"\(key)\":0,", with: "")
    json = json.replacingOccurrences(of: ",\"\(key)\":0", with: "")

    #expect(!json.contains(key), "\(key) must be gone from the JSON", sourceLocation: sourceLocation)
    return try #require(json.data(using: .utf8), sourceLocation: sourceLocation)
}

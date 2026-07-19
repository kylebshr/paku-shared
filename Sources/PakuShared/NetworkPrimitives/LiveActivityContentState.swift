import Foundation

/// The Live Activity `ContentState`, shared by the app (as
/// `AirQualityNearbyAttributes.ContentState`) and the server's push job.
/// Content-state bytes count against the APNs payload limit, so the compact
/// stored property names ARE the JSON keys — no CodingKeys — and nil
/// optionals are omitted entirely. Both sides encode/decode with default
/// `JSONEncoder`/`JSONDecoder` strategies (Dates are seconds-since-2001
/// doubles).
public struct LiveActivityContentState: Codable, Hashable, Sendable {
    /// One history point for the chart.
    public struct Point: Codable, Hashable, Sendable {
        /// timestamp
        public var t: Date

        /// AQI value (user's conversion applied), rounded
        public var v: Int16

        public init(t: Date, v: Int16) {
            self.t = t
            self.v = v
        }
    }

    /// sensor ID
    public var id: Int

    /// current AQI (user's conversion applied); UI formats zero-fraction
    public var a: Double

    /// trend: 1 = up, 0 = flat, -1 = down; nil = unknown (omitted)
    public var t: Int?

    /// distance to sensor in meters (last reported by the device); nil = unknown
    public var d: Double?

    /// sensor lastSeen
    public var ls: Date?

    /// chart history, oldest→newest, last 24 hours, ≤ 49 points
    /// (30-min buckets + current)
    public var h: [Point]?

    public init(
        id: Int,
        a: Double,
        t: Int?,
        d: Double?,
        ls: Date?,
        h: [Point]?
    ) {
        self.id = id
        self.a = a
        self.t = t
        self.d = d
        self.ls = ls
        self.h = h
    }
}

import Foundation

/// Which of a PurpleAir sensor's two PM channels (A and B) PurpleAir has
/// marked as downgraded — flagged as unreliable, automatically or by their
/// staff. The server excludes downgraded channels from the readings it
/// serves (like the PurpleAir map does); this reports what was excluded so
/// the app can say so.
public enum ChannelFlags: Int, Codable, Sendable {
    case normal = 0
    case aDowngraded = 1
    case bDowngraded = 2
    case bothDowngraded = 3

    /// Whether any channel is downgraded: readings come from the one
    /// healthy channel — or, with both downgraded, shouldn't be trusted.
    public var hasDowngradedChannel: Bool { self != .normal }
}

/// Which PM channels the sensor's hardware has (PurpleAir's
/// channel_state) — a hardware fact fixed at manufacture, unlike
/// `ChannelFlags`, which reports PurpleAir's live judgement of those
/// channels. Confidence only measures channel agreement on two-channel
/// hardware (`.both`); single-channel devices (PA-I, Touch) are pinned at
/// confidence 30 by PurpleAir, which isn't a warning signal.
public enum ChannelState: Int, Codable, Sendable {
    case noChannels = 0
    case aOnly = 1
    case bOnly = 2
    case both = 3
}

public struct SensorResponse: Codable, Sendable {
    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let locationType: LocationType
    public let lastSeen: Date
    public let altitude: Double?
    public let humidity: Double?
    public let confidence: Int?
    public let temperature: Double?
    public let pm2_5: Double?
    public let pm2_5_cf_1: Double?
    public let pm2_5_10minute: Double?
    public let pm2_5_30minute: Double?
    public let pm2_5_60minute: Double?
    public let pm1_0: Double?
    public let pm10_0: Double?
    public let voc: Double?

    /// Whether PurpleAir lists the sensor on the public map. nil when the
    /// crawl didn't report it (older servers, or the field wasn't fetched).
    public let isPublic: Bool?

    /// Which PM channels PurpleAir has downgraded. nil when the crawl
    /// didn't report it (older servers, or the field wasn't fetched).
    public let channelFlags: ChannelFlags?

    /// Which PM channels the hardware has. nil when the crawl didn't
    /// report it (older servers, or the field wasn't fetched).
    public let channelState: ChannelState?

    public init(
        id: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        locationType: LocationType,
        lastSeen: Date,
        altitude: Double? = nil,
        humidity: Double? = nil,
        confidence: Int? = nil,
        temperature: Double? = nil,
        pm2_5: Double? = nil,
        pm2_5_cf_1: Double? = nil,
        pm2_5_10minute: Double? = nil,
        pm2_5_30minute: Double? = nil,
        pm2_5_60minute: Double? = nil,
        pm1_0: Double? = nil,
        pm10_0: Double? = nil,
        voc: Double? = nil,
        isPublic: Bool? = nil,
        channelFlags: ChannelFlags? = nil,
        channelState: ChannelState? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.locationType = locationType
        self.lastSeen = lastSeen
        self.altitude = altitude
        self.humidity = humidity
        self.confidence = confidence
        self.temperature = temperature
        self.pm2_5 = pm2_5
        self.pm2_5_cf_1 = pm2_5_cf_1
        self.pm2_5_10minute = pm2_5_10minute
        self.pm2_5_30minute = pm2_5_30minute
        self.pm2_5_60minute = pm2_5_60minute
        self.pm1_0 = pm1_0
        self.pm10_0 = pm10_0
        self.voc = voc
        self.isPublic = isPublic
        self.channelFlags = channelFlags
        self.channelState = channelState
    }

    /// The keys `encode(to:)` writes. Every property key, plus the three
    /// long-window averages that no longer have stored properties. Kept
    /// separate from the synthesized `CodingKeys` so decoding stays
    /// synthesized and ignores the legacy keys entirely (new snapshots omit
    /// them).
    private enum WireCodingKeys: String, CodingKey {
        case id
        case name
        case latitude
        case longitude
        case locationType
        case lastSeen
        case altitude
        case humidity
        case confidence
        case temperature
        case pm2_5
        case pm2_5_cf_1
        case pm2_5_10minute
        case pm2_5_30minute
        case pm2_5_60minute
        case pm1_0
        case pm10_0
        case voc
        case isPublic
        case channelFlags
        case channelState
        case pm2_5_6hour
        case pm2_5_24hour
        case pm2_5_1week
    }

    /// Written by hand rather than synthesized because every released iOS
    /// app version requires `pm2_5_6hour`, `pm2_5_24hour` and `pm2_5_1week`
    /// to decode as non-nil for *every* sensor, and drops any sensor that is
    /// missing one. This type is the server's wire format, so those keys have
    /// to keep appearing; a constant 0 satisfies the old guard, and the
    /// values are unused by any current UI.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: WireCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(locationType, forKey: .locationType)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encodeIfPresent(humidity, forKey: .humidity)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(pm2_5, forKey: .pm2_5)
        try container.encodeIfPresent(pm2_5_cf_1, forKey: .pm2_5_cf_1)
        try container.encodeIfPresent(pm2_5_10minute, forKey: .pm2_5_10minute)
        try container.encodeIfPresent(pm2_5_30minute, forKey: .pm2_5_30minute)
        try container.encodeIfPresent(pm2_5_60minute, forKey: .pm2_5_60minute)
        try container.encodeIfPresent(pm1_0, forKey: .pm1_0)
        try container.encodeIfPresent(pm10_0, forKey: .pm10_0)
        try container.encodeIfPresent(voc, forKey: .voc)
        try container.encodeIfPresent(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(channelFlags, forKey: .channelFlags)
        try container.encodeIfPresent(channelState, forKey: .channelState)

        try container.encode(0 as Double, forKey: .pm2_5_6hour)
        try container.encode(0 as Double, forKey: .pm2_5_24hour)
        try container.encode(0 as Double, forKey: .pm2_5_1week)
    }
}

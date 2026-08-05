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
    public let pm2_5_6hour: Double?
    public let pm2_5_24hour: Double?
    public let pm2_5_1week: Double?
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
        altitude: Double?,
        humidity: Double?,
        confidence: Int?,
        temperature: Double?,
        pm2_5: Double?,
        pm2_5_cf_1: Double?,
        pm2_5_10minute: Double?,
        pm2_5_30minute: Double?,
        pm2_5_60minute: Double?,
        pm2_5_6hour: Double?,
        pm2_5_24hour: Double?,
        pm2_5_1week: Double?,
        pm1_0: Double?,
        pm10_0: Double?,
        voc: Double?,
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
        self.pm2_5_6hour = pm2_5_6hour
        self.pm2_5_24hour = pm2_5_24hour
        self.pm2_5_1week = pm2_5_1week
        self.pm1_0 = pm1_0
        self.pm10_0 = pm10_0
        self.voc = voc
        self.isPublic = isPublic
        self.channelFlags = channelFlags
        self.channelState = channelState
    }
}

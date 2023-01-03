import Foundation

public struct SensorResponse: Codable {
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
        pm2_5_6hour: Double? = nil,
        pm2_5_24hour: Double? = nil,
        pm2_5_1week: Double? = nil
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
    }
}

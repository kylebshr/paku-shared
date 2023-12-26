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
    public let pm1_0: Double?
    public let pm10_0: Double?
    public let voc: Double?

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
        voc: Double?
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
    }
}

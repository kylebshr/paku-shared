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
}

import Foundation

struct SensorResponse: Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let locationType: LocationType
    let lastSeen: Date
    let altitude: Double?
    let humidity: Double?
    let confidence: Int?
    let temperature: Double?
    let pm2_5: Double?
    let pm2_5_cf_1: Double?
    let pm2_5_10minute: Double?
    let pm2_5_30minute: Double?
    let pm2_5_60minute: Double?
    let pm2_5_6hour: Double?
    let pm2_5_24hour: Double?
    let pm2_5_1week: Double?
}

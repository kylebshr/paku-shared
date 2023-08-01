import Foundation

public struct SensorNotificationResponse: Codable, Hashable {
    public var id: UUID
    public var sensorID: Int
    public var sensorName: String
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool

    public init(
        id: UUID,
        sensorID: Int,
        sensorName: String,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool
    ) {
        self.id = id
        self.sensorID = sensorID
        self.sensorName = sensorName
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
    }
}

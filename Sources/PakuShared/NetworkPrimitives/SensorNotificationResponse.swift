import Foundation

public struct SensorNotificationResponse: Codable, Hashable, Sendable {
    public var id: UUID
    public var sensorID: Int
    public var sensorName: String
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool
    /// Optional so payloads cached before the field existed still decode;
    /// `nil` means false.
    public var isCritical: Bool?
    public var isNearestSensor: Bool

    public init(
        id: UUID,
        sensorID: Int,
        sensorName: String,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool,
        isCritical: Bool,
        isNearestSensor: Bool
    ) {
        self.id = id
        self.sensorID = sensorID
        self.sensorName = sensorName
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
        self.isCritical = isCritical
        self.isNearestSensor = isNearestSensor
    }
}

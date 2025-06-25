import Foundation

public struct NearestSensorSubscriptionResponse: Codable, Sendable {
    public var currentSensorID: Int
    public var currentSensorName: String
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool
    public var updatedAt: Date?
    public var lastWidgetUpdate: Date
    
    public init(
        currentSensorID: Int,
        currentSensorName: String,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool,
        updatedAt: Date?,
        lastWidgetUpdate: Date
    ) {
        self.currentSensorID = currentSensorID
        self.currentSensorName = currentSensorName
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
        self.updatedAt = updatedAt
        self.lastWidgetUpdate = lastWidgetUpdate
    }
}

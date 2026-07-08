import Foundation

public struct NearestSensorSubscriptionResponse: Codable, Sendable {
    /// The device that currently owns location monitoring for this user. A
    /// client compares this to its own device ID to know whether it is the
    /// owner or the subscription is active on another device.
    public var deviceID: UUID
    public var currentSensorID: Int?
    public var currentSensorName: String?
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool
    public var updatedAt: Date?
    public var lastReportedAt: Date

    public init(
        deviceID: UUID,
        currentSensorID: Int?,
        currentSensorName: String?,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool,
        updatedAt: Date?,
        lastReportedAt: Date
    ) {
        self.deviceID = deviceID
        self.currentSensorID = currentSensorID
        self.currentSensorName = currentSensorName
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
        self.updatedAt = updatedAt
        self.lastReportedAt = lastReportedAt
    }
}

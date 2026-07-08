import Foundation

public struct CreateNearestSensorSubscriptionRequest: Codable, Sendable {
    public var userID: UUID
    /// Identifies the device that owns location monitoring for this user. Only
    /// one device per user owns the subscription; creating claims ownership.
    public var deviceID: UUID
    public var sensorID: Int?
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool

    public init(
        userID: UUID,
        deviceID: UUID,
        sensorID: Int? = nil,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool
    ) {
        self.userID = userID
        self.deviceID = deviceID
        self.sensorID = sensorID
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
    }
}

public struct UpdateNearestSensorRequest: Codable, Sendable {
    public var userID: UUID
    /// The reporting device. The server only accepts reports from the device
    /// that owns the subscription.
    public var deviceID: UUID
    public var sensorID: Int?

    public init(userID: UUID, deviceID: UUID, sensorID: Int?) {
        self.userID = userID
        self.deviceID = deviceID
        self.sensorID = sensorID
    }
}

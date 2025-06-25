import Foundation

public struct CreateNearestSensorSubscriptionRequest: Codable, Sendable {
    public var userID: UUID
    public var sensorID: Int
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod
    public var sendBelowThreshold: Bool
    
    public init(
        userID: UUID,
        sensorID: Int,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod,
        sendBelowThreshold: Bool
    ) {
        self.userID = userID
        self.sensorID = sensorID
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
        self.sendBelowThreshold = sendBelowThreshold
    }
}

public struct UpdateNearestSensorRequest: Codable, Sendable {
    public var userID: UUID
    public var sensorID: Int
    
    public init(userID: UUID, sensorID: Int) {
        self.userID = userID
        self.sensorID = sensorID
    }
}

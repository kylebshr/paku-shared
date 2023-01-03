//
//  File.swift
//  
//
//  Created by Kyle Bashour on 12/22/22.
//

import Foundation

public struct SensorNotificationRequest: Codable {
    public var userID: UUID
    public var sensorID: Int
    public var threshold: Int
    public var conversion: AQIConversion
    public var averagingPeriod: AverageTimePeriod

    public init(
        userID: UUID,
        sensorID: Int,
        threshold: Int,
        conversion: AQIConversion,
        averagingPeriod: AverageTimePeriod
    ) {
        self.userID = userID
        self.sensorID = sensorID
        self.threshold = threshold
        self.conversion = conversion
        self.averagingPeriod = averagingPeriod
    }
}

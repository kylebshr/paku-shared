//
//  File.swift
//  
//
//  Created by Kyle Bashour on 12/22/22.
//

import Foundation

struct SensorNotificationRequest: Codable {
    var userID: UUID
    var sensorID: Int
    var threshold: Int
    var conversion: AQIConversion
    var averagingPeriod: AverageTimePeriod
}

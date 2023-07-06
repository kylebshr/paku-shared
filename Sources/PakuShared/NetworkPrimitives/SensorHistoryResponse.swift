//
//  SensorHistoryResponse.swift
//
//
//  Created by Kyle Bashour on 6/20/23.
//

import Foundation

public struct SensorHistoryResponse: Codable {
    public struct DataPoint: Codable {
        public var timestamp: Date
        public var pm1_0: Double?
        public var pm2_5: Double?
        public var pm10_0: Double?
        public var humidity: Int?
        public var temperature: Int?
        public var confidence: Int?

        public init(
            timestamp: Date,
            pm1_0: Double?,
            pm2_5: Double?,
            pm10_0: Double?,
            humidity: Double?,
            temperature: Double?,
            confidence: Int?
        ) {
            self.timestamp = timestamp
            self.pm1_0 = pm1_0
            self.pm2_5 = pm2_5
            self.pm10_0 = pm10_0
            self.humidity = humidity.map(Int.init)
            self.temperature = temperature.map(Int.init)
            self.confidence = confidence
        }
    }

    public var sensorID: Int
    public var data: [DataPoint]

    public init(sensorID: Int, data: [DataPoint]) {
        self.sensorID = sensorID
        self.data = data
    }
}

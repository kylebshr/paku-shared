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
        public var pm2_5_60minute: Double?
        public var humidity: Int?
        public var temperature: Int?
        public var confidence: Int?

        public init(
            timestamp: Date,
            pm2_5_60minute: Double? = nil,
            humidity: Double? = nil,
            temperature: Double? = nil,
            confidence: Int? = nil
        ) {
            self.timestamp = timestamp
            self.pm2_5_60minute = pm2_5_60minute
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

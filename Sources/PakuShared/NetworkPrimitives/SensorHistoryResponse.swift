//
//  SensorHistoryResponse.swift
//
//
//  Created by Kyle Bashour on 6/20/23.
//

import Foundation

public struct SensorHistoryResponse: Codable {
    public struct DataPoint: Codable {
        var timestamp: Date
        var pm2_5_60minute: Double?
        var humidity: Double?
        var temperature: Double?
        var confidence: Int?
    }

    public var sensorID: Int
    public var data: [DataPoint]

    public init(sensorID: Int, data: [DataPoint]) {
        self.sensorID = sensorID
        self.data = data
    }
}

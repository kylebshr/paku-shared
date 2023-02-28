//
//  File.swift
//  
//
//  Created by Kyle Bashour on 2/28/23.
//

import Foundation

public struct RegisterPrivateSensorRequest: Codable {
    public var userID: UUID
    public var sensorID: String
    public var ownerEmail: String

    public init(userID: UUID, sensorID: String, ownerEmail: String) {
        self.userID = userID
        self.sensorID = sensorID
        self.ownerEmail = ownerEmail
    }
}

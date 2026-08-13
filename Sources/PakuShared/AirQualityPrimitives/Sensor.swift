import Foundation

public struct Sensor: Codable, Equatable, Identifiable, Hashable, Sendable {
    public enum InitError: Error, Sendable {
        case missingField
    }

    public let id: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let locationType: LocationType
    public let lastSeen: Date
    public let altitude: Double?
    public let humidity: Int?
    public let temperature: Int?
    public let confidence: Int?
    public let pm2_5: Double
    public let pm2_5_cf_1: Double
    public let pm2_5_10minute: Double
    public let pm2_5_30minute: Double
    public let pm2_5_60minute: Double
    public let pm1_0: Double?
    public let pm10_0: Double?
    public let voc: Double?
    public let channelFlags: ChannelFlags?
    public let isPrivateSensor: Bool

    public init(response: SensorResponse, isPrivateSensor: Bool = false) throws {
        guard
            let pm2_5 = response.pm2_5,
            let pm2_5_cf_1 = response.pm2_5_cf_1,
            let pm2_5_10minute = response.pm2_5_10minute,
            let pm2_5_30minute = response.pm2_5_30minute,
            let pm2_5_60minute = response.pm2_5_60minute
        else {
            throw InitError.missingField
        }

        self.id = response.id
        self.name = response.name
        self.latitude = response.latitude
        self.longitude = response.longitude
        self.locationType = response.locationType
        self.lastSeen = response.lastSeen
        self.altitude = response.altitude
        self.humidity = response.humidity.map(Int.init)
        self.confidence = response.confidence
        self.temperature = response.temperature.map(Int.init)
        self.pm2_5 = pm2_5
        self.pm2_5_cf_1 = pm2_5_cf_1
        self.pm2_5_10minute = pm2_5_10minute
        self.pm2_5_30minute = pm2_5_30minute
        self.pm2_5_60minute = pm2_5_60minute
        self.pm1_0 = response.pm1_0
        self.pm10_0 = response.pm10_0
        self.voc = response.voc
        self.channelFlags = response.channelFlags
        self.isPrivateSensor = isPrivateSensor
    }

    public func aqiValue(
        period: AverageTimePeriod,
        conversion: AQIConversion
    ) -> Double {
        let pm2_5 = self.pm2_5(for: period)
        return AQI.value(
            for: pm2_5,
            humidity: humidity,
            conversion: resolvedConversion(conversion),
            location: locationType
        )
    }

    public func aqhiValue(
        period: AverageTimePeriod,
        conversion: AQIConversion
    ) -> Double {
        let pm2_5 = self.pm2_5(for: period)
        return AQI.aqhi(
            for: pm2_5,
            humidity: humidity,
            conversion: resolvedConversion(conversion),
            location: locationType
        )
    }

    public func aqhiPlusValue(
        period: AverageTimePeriod,
        conversion: AQIConversion
    ) -> Double {
        let pm2_5 = self.pm2_5(for: period)
        return AQI.aqhiPlus(
            for: pm2_5,
            humidity: humidity,
            conversion: resolvedConversion(conversion),
            location: locationType
        )
    }

    /// The EPA conversion corrects the ~50% high-concentration over-read
    /// of Plantower particle counters, which PurpleAir and AirGradient
    /// monitors share — AirGradient validated the same EPA equation on
    /// their hardware, and co-located pairs agree most tightly with both
    /// networks corrected. A future reference-grade source (regulatory
    /// monitors via OpenAQ/AirNow) must resolve to `.none` here: its
    /// readings have no counter bias to correct.
    private func resolvedConversion(_ conversion: AQIConversion) -> AQIConversion {
        switch source {
        case .purpleAir, .airGradient: conversion
        }
    }

    public func pm2_5(for period: AverageTimePeriod) -> Double {
        switch period {
        case .now:
            return pm2_5
        case .tenMinutes:
            return pm2_5_10minute
        case .halfHour:
            return pm2_5_30minute
        case .oneHour:
            return pm2_5_60minute
        }
    }

    public func aqiCategory(period: AverageTimePeriod, conversion: AQIConversion) -> AQICategory {
        return AQICategory(aqi: aqiValue(period: period, conversion: conversion))
    }

    public func aqhiCategory(period: AverageTimePeriod, conversion: AQIConversion) -> AQHICategory {
        return AQHICategory(aqhi: aqhiValue(period: period, conversion: conversion).rounded(.up))
    }
}

extension Sensor: Comparable {
    public static func < (lhs: Sensor, rhs: Sensor) -> Bool {
        lhs.name.hashValue < rhs.name.hashValue
    }
}

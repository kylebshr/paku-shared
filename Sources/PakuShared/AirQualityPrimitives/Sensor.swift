import Foundation

public struct Sensor: Codable, Equatable, Identifiable {
    public enum InitError: Error {
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
    public let pm2_5_6hour: Double
    public let pm2_5_24hour: Double
    public let pm2_5_1week: Double
    public let pm1_0: Double?
    public let pm10_0: Double?
    public let isPrivateSensor: Bool

    public init(response: SensorResponse, isPrivateSensor: Bool = false) throws {
        guard
            let pm2_5 = response.pm2_5,
            let pm2_5_cf_1 = response.pm2_5_cf_1,
            let pm2_5_10minute = response.pm2_5_10minute,
            let pm2_5_30minute = response.pm2_5_30minute,
            let pm2_5_60minute = response.pm2_5_60minute,
            let pm2_5_6hour = response.pm2_5_6hour,
            let pm2_5_24hour = response.pm2_5_24hour,
            let pm2_5_1week = response.pm2_5_1week
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
        self.pm2_5_6hour = pm2_5_6hour
        self.pm2_5_24hour = pm2_5_24hour
        self.pm2_5_1week = pm2_5_1week
        self.pm1_0 = response.pm1_0
        self.pm10_0 = response.pm10_0
        self.isPrivateSensor = isPrivateSensor
    }

    public func aqiValue(
        period: AverageTimePeriod,
        conversion: AQIConversion
    ) -> Double {
        let pm2_5 = self.pm2_5(for: period, conversion: conversion)

        switch conversion {
        case .none:
            return aqiFrom(pm: pm2_5)
        case .EPA:
            return epaAQI(pm2_5: pm2_5)
        }
    }

    public func pm2_5(for period: AverageTimePeriod, conversion: AQIConversion) -> Double {
        switch period {
        case .now:
            return conversion == .EPA ? pm2_5_cf_1 : pm2_5
        case .tenMinutes:
            return pm2_5_10minute
        case .halfHour:
            return pm2_5_30minute
        case .oneHour:
            return pm2_5_60minute
        case .sixHours:
            return pm2_5_6hour
        case .day:
            return pm2_5_24hour
        case .week:
            return pm2_5_1week
        }
    }

    public func aqiCategory(period: AverageTimePeriod, conversion: AQIConversion) -> AQICategory {
        return AQICategory(aqi: aqiValue(period: period, conversion: conversion))
    }

    // AQI Properties

    private func aqanduAQI(pm2_5: Double) -> Double {
        aqiFrom(pm: 0.778 * pm2_5 + 2.65).aqiClamped()
    }

    private func epaAQI(pm2_5: Double) -> Double {
        aqiFrom(pm: (0.534 * pm2_5) - (0.0844 * Double(humidity ?? 35)) + 5.604).aqiClamped()
    }

    private func aqiFrom(pm: Double) -> Double {
        if pm > 350.5 {
            return calcAQI(Cp: pm, Ih: 500, Il: 401, BPh: 500, BPl: 350.5)
        } else if pm > 250.5 {
            return calcAQI(Cp: pm, Ih: 400, Il: 301, BPh: 350.4, BPl: 250.5)
        } else if pm > 150.5 {
            return calcAQI(Cp: pm, Ih: 300, Il: 201, BPh: 250.4, BPl: 150.5)
        } else if pm > 55.5 {
            return calcAQI(Cp: pm, Ih: 200, Il: 151, BPh: 150.4, BPl: 55.5)
        } else if pm > 35.5 {
            return calcAQI(Cp: pm, Ih: 150, Il: 101, BPh: 55.4, BPl: 35.5)
        } else if pm > 12.1 {
            return calcAQI(Cp: pm, Ih: 100, Il: 51, BPh: 35.4, BPl: 12.1)
        } else if pm >= 0 {
            return calcAQI(Cp: pm, Ih: 50, Il: 0, BPh: 12, BPl: 0)
        } else {
            return 0
        }
    }

    private func calcAQI(Cp: Double, Ih: Double, Il: Double, BPh: Double, BPl: Double) -> Double {
        // The AQI equation https://forum.airnowtech.org/t/the-aqi-equation/169
        let a = Ih - Il;
        let b = BPh - BPl;
        let c = Cp - BPl;
        return round((a / b) * c + Il).aqiClamped()
    }
}

private extension Double {
    func aqiClamped() -> Double {
        return max(self, 0)
    }
}

extension Sensor: Comparable {
    public static func < (lhs: Sensor, rhs: Sensor) -> Bool {
        lhs.name.hashValue < rhs.name.hashValue
    }
}

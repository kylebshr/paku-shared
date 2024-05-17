//
//  File.swift
//  
//
//  Created by Kyle Bashour on 6/21/23.
//

import Foundation
import Numerics

public enum AQI {
    public static func value(
        for pm2_5: Double,
        humidity: Int?,
        conversion: AQIConversion,
        location: LocationType
    ) -> Double {
        aqiFrom(pm: correctedPM2_5(
            for: pm2_5,
            humidity: humidity,
            conversion: conversion,
            location: location
        ))
    }

    public static func aqhi(
        for pm2_5: Double,
        humidity: Int?,
        conversion: AQIConversion,
        location: LocationType
    ) -> Double {
        let pm = correctedPM2_5(
            for: pm2_5,
            humidity: humidity,
            conversion: conversion,
            location: location
        )

        let value = (1000 / 10.4) * (pow(Double.exp(1), 0.000487 * pm) - 1)
        return max(value, 1)
    }

    public static func correctedPM2_5(
        for pm2_5: Double,
        humidity: Int?,
        conversion: AQIConversion,
        location: LocationType
    ) -> Double {
        switch conversion {
        case .none:
            return pm2_5
        case .EPA:
            if location == .indoors {
                return epaCF_PM2_5(pm2_5: pm2_5, humidity: humidity)
            } else {
                return epaATM_PM2_5(pm2_5: pm2_5, humidity: humidity)
            }
        }
    }

    private static func epaCF_PM2_5(pm2_5: Double, humidity: Int?) -> Double {
        let e = Double(humidity ?? 25)
        let t = pm2_5

        if t > 343 {
            return 0.46 * t + 3.93 * pow(10, -4) * pow(t, 2) + 2.97
        } else {
            return 0.52 * t - 0.086 * e + 5.75
        }
    }


    private static func epaATM_PM2_5(pm2_5: Double, humidity: Int?) -> Double {
        let e = Double(humidity ?? 25)
        let t = pm2_5

        func t260() -> Double {
            2.966 + 0.69 * t + 8.84 * pow(10, -4) * pow(t, 2)
        }

        func t210() -> Double {
            (0.69 * (t / 50 - 4.2) + 0.786 * (1 - (t / 50 - 4.2))) * t - 0.0862 * e * (1 - (t / 50 - 4.2)) + 2.966 * (t / 50 - 4.2) + 5.75 * (1 - (t / 50 - 4.2)) + 8.84 * pow(10, -4) * pow(t, 2) * (t / 50 - 4.2)
        }

        func t50() -> Double {
            0.786 * t - 0.0862 * e + 5.75
        }

        func t30() -> Double {
            (0.786 * (t / 20 - 1.5) + 0.524 * (1 - (t / 20 - 1.5))) * t - 0.0862 * e + 5.75
        }

        func d() -> Double {
            0.524 * t - 0.0862 * e + 5.75
        }

        if t >= 260 {
            return t260()
        } else if t >= 210 {
            return t210()
        } else if t >= 50 {
            return t50()
        } else if t >= 30 {
            return t30()
        } else {
            return d()
        }
    }

    private static func aqiFrom(pm: Double) -> Double {
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

    private static func calcAQI(Cp: Double, Ih: Double, Il: Double, BPh: Double, BPl: Double) -> Double {
        // The AQI equation https://forum.airnowtech.org/t/the-aqi-equation/169
        let a = Ih - Il;
        let b = BPh - BPl;
        let c = Cp - BPl;
        return ((a / b) * c + Il)
            .aqiClamped()
    }
}

private extension Double {
    func aqiClamped() -> Double {
        return max(self, 0)
    }
}

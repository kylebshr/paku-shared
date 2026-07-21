import Foundation

/// The Live Activity `ContentState`, shared by the app (as
/// `AirQualityNearbyAttributes.ContentState`) and the server's push job.
/// Content-state bytes count against the APNs payload limit, so the compact
/// stored property names ARE the JSON keys — no CodingKeys — and nil
/// optionals are omitted entirely. Both sides encode/decode with default
/// `JSONEncoder`/`JSONDecoder` strategies (Dates are seconds-since-2001
/// doubles).
public struct LiveActivityContentState: Codable, Hashable, Sendable {
    /// One history point for the chart.
    public struct Point: Codable, Hashable, Sendable {
        /// timestamp
        public var t: Date

        /// AQI value (user's conversion applied), rounded
        public var v: Int16

        public init(t: Date, v: Int16) {
            self.t = t
            self.v = v
        }
    }

    /// sensor ID
    public var id: Int

    /// current AQI (user's conversion applied); UI formats zero-fraction
    public var a: Double

    /// trend: 1 = up, 0 = flat, -1 = down; nil = unknown (omitted)
    public var t: Int?

    /// distance to sensor in meters (last reported by the device); nil = unknown
    public var d: Double?

    /// sensor lastSeen
    public var ls: Date?

    /// chart history, oldest→newest, last 24 hours, ≤ 49 points
    /// (half-hourly rows + current)
    public var h: [Point]?

    public init(
        id: Int,
        a: Double,
        t: Int?,
        d: Double?,
        ls: Date?,
        h: [Point]?
    ) {
        self.id = id
        self.a = a
        self.t = t
        self.d = d
        self.ls = ls
        self.h = h
    }
}

extension LiveActivityContentState {
    /// Builds the content state. Shared by the app and the server's push
    /// job so both construct identical states; pure (the clock is a
    /// parameter) for testability.
    public static func build(
        sensor: Sensor,
        conversion: AQIConversion,
        distance: Double?,
        history: [SensorHistoryResponse.DataPoint],
        now: Date = .now
    ) -> LiveActivityContentState {
        let aqi = sensor.aqiValue(period: .now, conversion: conversion)

        func aqiValue(for point: SensorHistoryResponse.DataPoint) -> Double? {
            guard let pm2_5 = point.pm2_5 else {
                return nil
            }

            return AQI.value(
                for: pm2_5,
                humidity: point.humidity,
                conversion: conversion,
                location: sensor.locationType
            )
        }

        // The current reading is stamped at lastSeen, clamped so a
        // clock-skewed sensor can't push it past `now`. The same bound drops
        // history rows newer than lastSeen — the server stamps rows with the
        // crawl time even for a sensor that's stopped reporting, so those
        // carry frozen data.
        let currentTimestamp = min(sensor.lastSeen, now)

        // Trend: the sensor's own fast average crossed against its slow
        // one — reacts to a spike in minutes and needs no history, so an
        // arrow renders even when the history query comes back empty.
        let direction: TrendDirection? = if now.timeIntervalSince(sensor.lastSeen) > TrendDirection.stalenessLimit {
            nil
        } else {
            .between(
                fast: sensor.aqiValue(period: .tenMinutes, conversion: conversion),
                slow: sensor.aqiValue(period: .oneHour, conversion: conversion),
                deadband: TrendDeadband.aqi
            )
        }

        let trend: Int? = switch direction {
        case .up: 1
        case .flat: 0
        case .down: -1
        case nil: nil
        }

        // History rows are half-hourly, so 24 hours plus the current point
        // is at most 49 points — the APNs payload cap; suffix() drops the
        // oldest on the rare straddle.
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)

        var points = history
            .filter { $0.timestamp > cutoff && $0.timestamp <= currentTimestamp }
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap { point in
                aqiValue(for: point).map {
                    Point(t: point.timestamp, v: Int16(clamping: Int($0.rounded())))
                }
            }

        points.append(Point(t: currentTimestamp, v: Int16(clamping: Int(aqi.rounded()))))

        return LiveActivityContentState(
            id: sensor.id,
            a: aqi,
            t: trend,
            d: distance,
            ls: sensor.lastSeen,
            h: Array(points.suffix(49))
        )
    }
}


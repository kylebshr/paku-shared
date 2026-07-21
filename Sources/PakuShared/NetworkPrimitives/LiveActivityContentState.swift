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
    /// Builds the content state from a sensor's current reading, the user's
    /// conversion, the last reported distance, and the sensor's history.
    /// Shared by the app (the initial request, local foreground refreshes,
    /// and widget previews) and the server's push job, so both sides
    /// construct identical states. Pure (the clock is a parameter), so the
    /// trend and history-window rules are unit-testable.
    public static func build(
        sensor: Sensor,
        conversion: AQIConversion,
        distance: Double?,
        history: [SensorHistoryResponse.DataPoint],
        now: Date = .now
    ) -> LiveActivityContentState {
        let aqi = sensor.aqiValue(period: .now, conversion: conversion)

        func aqiValue(for point: SensorHistoryResponse.DataPoint) -> Double? {
            // The window's peak where the server recorded one, so a spike
            // between snapshots survives to the chart — matching the app's
            // charts. Rows without one (older servers, sensors that weren't
            // reporting) fall back to the sampled value.
            guard let pm2_5 = point.pm2_5_max ?? point.pm2_5 else {
                return nil
            }

            return AQI.value(
                for: pm2_5,
                humidity: point.humidity,
                conversion: conversion,
                location: sensor.locationType
            )
        }

        // The current reading is stamped at lastSeen, never in the future:
        // a clock-skewed sensor must not push the newest point past `now`,
        // and everything older is clamped to it so the points stay
        // ascending. History rows newer than lastSeen carry frozen data —
        // the server stamps rows with the crawl time even for a sensor
        // that's stopped reporting — so the same bound drops those too.
        let currentTimestamp = min(sensor.lastSeen, now)

        // Trend: the sensor's own 10-minute average crossed against its
        // 60-minute one. Both come off the sensor itself, computed from
        // readings every couple of minutes, so this reacts to a spike in
        // minutes where the 30-minute history rows would take half an hour
        // — and it needs no history at all, so an arrow still renders when
        // the history query comes back empty. Shared with the app's widget
        // and watch arrows so every surface agrees for the same sensor.
        // A quiet sensor's averages are frozen; nothing to report.
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

        // History: the last 24 hours of rows, oldest→newest, with the
        // current reading closing out the series at its raw timestamp. The
        // server writes one row per half hour, so a window holds at most 48
        // rows — with the current point appended that sits exactly at the
        // ≤49-point / 4KB APNs cap, and suffix() drops the oldest on the
        // rare straddle.
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


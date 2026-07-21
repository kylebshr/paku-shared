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
    /// (30-min buckets + current)
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

        // The current reading is stamped at lastSeen, never in the future:
        // a clock-skewed sensor must not push the newest point past `now`,
        // and everything older is clamped to it so the points stay
        // ascending. History rows newer than lastSeen carry frozen data —
        // the server stamps rows with the crawl time even for a sensor
        // that's stopped reporting — so the same bound drops those too.
        let currentTimestamp = min(sensor.lastSeen, now)

        // Trend: the slope of the last hour of readings, anchored by the
        // current reading. Shared with the app's widget/watch arrows so
        // every surface classifies the same readings the same way. Under 15
        // minutes of span there's too little signal — leave `t` unset.
        let lookback = now.addingTimeInterval(-60 * 60)
        var trendSamples: [(date: Date, value: Double)] = history.compactMap { point in
            guard point.timestamp > lookback, point.timestamp <= currentTimestamp,
                  let value = aqiValue(for: point)
            else {
                return nil
            }

            return (date: point.timestamp, value: value)
        }
        trendSamples.append((date: currentTimestamp, value: aqi))

        let trend: Int? = switch TrendDirection.of(
            samples: trendSamples,
            deadbandPerHour: trendDeadbandAQIPerHour
        ) {
        case .up: 1
        case .flat: 0
        case .down: -1
        case nil: nil
        }

        // History: thin the last 24 hours to at most one point per 30
        // minutes. This is a payload guard, not a grid — the client re-bins
        // whatever cadence it's given — so its only jobs are staying under
        // the ≤49-point / 4KB APNs cap and staying robust to input denser
        // than the server's half-hourly snapshots.
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        let bucketLength: TimeInterval = 30 * 60

        var buckets: [Int: [(timestamp: Date, value: Double)]] = [:]
        for point in history where point.timestamp > cutoff && point.timestamp <= currentTimestamp {
            guard let value = aqiValue(for: point) else { continue }
            let bucket = Int(point.timestamp.timeIntervalSinceReferenceDate / bucketLength)
            buckets[bucket, default: []].append((point.timestamp, value))
        }

        // Thinned points carry the bucket's *worst* reading, matching the
        // app's health-index bins — averaging here would dilute a spike
        // before the chart ever sees it.
        var points = buckets.keys.sorted().map { key in
            let entries = buckets[key]!
            return Point(
                t: entries.map(\.timestamp).max()!,
                v: Int16(clamping: Int(entries.map(\.value).max()!.rounded()))
            )
        }

        // The current reading closes out the series at its raw timestamp.
        // A duplicate stamp against the newest thinned point is fine — the
        // client bins them together. Capped at 49 points, oldest dropped.
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

/// AQI change per hour below which movement reads as sensor jitter rather
/// than a trend. Mirrors the app's `.airQuality` deadband so a Live
/// Activity's arrow agrees with the widget's for the same sensor.
private let trendDeadbandAQIPerHour: Double = 4

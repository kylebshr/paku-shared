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

        // Trend: the current reading vs the average of the last hour of
        // history. No points in the last hour → unknown.
        let lookback = now.addingTimeInterval(-60 * 60)
        let recentValues = history
            .filter { $0.timestamp > lookback }
            .compactMap(aqiValue(for:))

        let trend: Int?
        if recentValues.isEmpty {
            trend = nil
        } else {
            let average = recentValues.average()
            if Int(average) == Int(aqi) {
                trend = 0
            } else if aqi > average {
                trend = 1
            } else {
                trend = -1
            }
        }

        // History: bin the last 24 hours into the 30-minute cadence the
        // server's snapshots sit on — on already-half-hour-stamped rows this
        // degenerates to the same points, and it keeps the function robust
        // to arbitrary input. Buckets are clamped to lastSeen: the server
        // stamps history rows with the crawl time even for a sensor that's
        // stopped reporting, so an offline sensor accrues buckets newer than
        // lastSeen carrying frozen data — dropping them keeps the points
        // ascending after the synthetic current point is appended.
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        let bucketLength: TimeInterval = 30 * 60

        var buckets: [Int: [(timestamp: Date, value: Double)]] = [:]
        for point in history where point.timestamp > cutoff && point.timestamp <= sensor.lastSeen {
            guard let value = aqiValue(for: point) else { continue }
            let bucket = Int(point.timestamp.timeIntervalSinceReferenceDate / bucketLength)
            buckets[bucket, default: []].append((point.timestamp, value))
        }

        var points = buckets.keys.sorted().map { key in
            let entries = buckets[key]!
            return Point(
                t: entries.map(\.timestamp).max()!,
                v: Int16(clamping: Int(entries.map(\.value).average().rounded()))
            )
        }

        // Stamp the current reading on the same half-hour grid as the
        // history so the final bar lines up with the others, and replace
        // any bucket it collides with — appending at raw lastSeen can land
        // minutes from the newest bucket, drawing two overlapping bars.
        // Capped at 49 points (a 24-hour window straddles at most 49
        // half-hour grid slots), dropping the oldest first.
        let syntheticTimestamp = sensor.lastSeen.nearestHalfHour()
        points.removeAll { $0.t >= syntheticTimestamp }
        points.append(Point(t: syntheticTimestamp, v: Int16(clamping: Int(aqi.rounded()))))

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

extension Date {
    /// The half-hour grid the history snapshots sit on; the content-state
    /// builder aligns its synthetic current point to the same grid.
    func nearestHalfHour() -> Date {
        let precision: TimeInterval = 30 * 60
        let seconds = (timeIntervalSinceReferenceDate / precision).rounded() * precision
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}

extension [Double] {
    /// The arithmetic mean; callers guarantee a non-empty array.
    func average() -> Double {
        reduce(0, +) / Double(count)
    }
}

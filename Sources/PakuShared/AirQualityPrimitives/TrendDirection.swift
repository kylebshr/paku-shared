import Foundation

/// How much movement reads as sensor jitter rather than a trend, per kind
/// of reading. Shared so the server's Live Activity arrow can't drift from
/// the widget's. Tuned by eye; adjust freely.
public enum TrendDeadband {
    // Level differences, in displayed units — see
    // ``TrendDirection/between(fast:slow:deadband:)``.

    public static let aqi: Double = 3
    public static let aqhi: Double = 0.3
    public static let pm2_5: Double = 1.5

    // Rates of change, in units per hour — see
    // ``TrendDirection/of(samples:deadbandPerHour:)``.

    public static let temperature: Double = 1.5
    public static let humidity: Double = 3
    public static let pm1_0: Double = 1.5
    public static let pm10_0: Double = 3
    public static let voc: Double = 30
}

/// Which way a reading has been heading. Shared by the app's arrows and the
/// server's Live Activity push job.
public enum TrendDirection: Equatable, Hashable, Codable, Sendable {
    case up
    case flat
    case down

    /// How far back the slope fit looks. History rows are 30 minutes apart,
    /// so anything shorter gives the fit too few samples.
    public static let slopeLookback: TimeInterval = 2 * 60 * 60

    /// A sensor quiet longer than this has frozen averages and a frozen
    /// history tail — callers report no trend.
    public static let stalenessLimit: TimeInterval = 60 * 60
}

extension TrendDirection {
    /// A fast average crossed against a slow one; `deadband` is a level
    /// difference in the displayed units.
    ///
    /// Preferred for anything derived from PM2.5: the sensor's own 10- and
    /// 60-minute averages react to a spike within minutes and need no
    /// history fetch. The slow window contains the fast one, so after a step
    /// change this reads as moving until the slow average catches up —
    /// intended: "higher than the hour behind it".
    public static func between(fast: Double, slow: Double, deadband: Double) -> TrendDirection {
        let difference = fast - slow
        if abs(difference) < deadband {
            return .flat
        } else {
            return difference > 0 ? .up : .down
        }
    }

    /// The direction of a least-squares fit through timestamped readings:
    /// flat inside ±`deadbandPerHour`, `nil` when they span less than 15
    /// minutes (which also covers empty and single-reading input).
    public static func of(
        samples: [(date: Date, value: Double)],
        deadbandPerHour: Double
    ) -> TrendDirection? {
        guard let first = samples.map(\.date).min(),
              let last = samples.map(\.date).max(),
              last.timeIntervalSince(first) >= 15 * 60
        else {
            return nil
        }

        let hours = samples.map { $0.date.timeIntervalSince(first) / 3600 }
        let values = samples.map(\.value)
        let count = Double(samples.count)
        let meanHours = hours.reduce(0, +) / count
        let meanValue = values.reduce(0, +) / count

        var numerator = 0.0
        var denominator = 0.0
        for (hour, value) in zip(hours, values) {
            numerator += (hour - meanHours) * (value - meanValue)
            denominator += (hour - meanHours) * (hour - meanHours)
        }

        guard denominator > 0 else { return nil }

        let slopePerHour = numerator / denominator
        if abs(slopePerHour) < deadbandPerHour {
            return .flat
        } else {
            return slopePerHour > 0 ? .up : .down
        }
    }
}

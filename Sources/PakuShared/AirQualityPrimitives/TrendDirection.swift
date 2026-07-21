import Foundation

/// How much movement reads as sensor jitter rather than a trend, per kind
/// of reading. Lives here rather than in the app so the server's Live
/// Activity arrow can't drift from the widget's for the same sensor.
///
/// Tuned by eye against typical clean-air noise; adjust freely.
public enum TrendDeadband {
    // Level differences between a fast and a slow average, in displayed
    // units — see ``TrendDirection/between(fast:slow:deadband:)``.

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

/// Which way a reading has been heading. Shared by the app's widget/watch
/// arrows and the server's Live Activity push job so both classify the same
/// readings the same way.
public enum TrendDirection: Equatable, Hashable, Codable, Sendable {
    case up
    case flat
    case down

    /// How far back the slope fit looks. Two hours rather than one: the
    /// history rows it reads are 30 minutes apart, so an hour is two rows
    /// plus the current reading — too few for a fit to mean anything beyond
    /// its endpoints. The kinds still using a slope are slow-moving ones
    /// where a two-hour tendency is the more useful question anyway.
    public static let slopeLookback: TimeInterval = 2 * 60 * 60

    /// A sensor quiet longer than this has frozen averages and a frozen
    /// history tail, so neither method describes anything current — callers
    /// report no trend.
    public static let stalenessLimit: TimeInterval = 60 * 60
}

extension TrendDirection {
    /// Where a reading is heading, from a fast average crossed against a
    /// slow one — both already in the units being displayed, so `deadband`
    /// is a plain level difference.
    ///
    /// Preferred over ``of(samples:deadbandPerHour:)`` for anything derived
    /// from PM2.5, because the sensor publishes its own 10- and 60-minute
    /// averages computed from ~2-minute readings. Those are far finer than
    /// the 30-minute history rows can reconstruct, they react to a spike
    /// within minutes instead of half an hour, and they need no history
    /// fetch — so an arrow still renders when history is missing.
    ///
    /// Note the slow window *contains* the fast one, so after a step change
    /// this reads as moving until the slow average catches up rather than
    /// snapping back to flat. That is the intended meaning: "higher than
    /// the hour behind it", not "changed since the last sample".
    public static func between(fast: Double, slow: Double, deadband: Double) -> TrendDirection {
        let difference = fast - slow
        if abs(difference) < deadband {
            return .flat
        } else {
            return difference > 0 ? .up : .down
        }
    }

    /// The direction of a least-squares line fit through timestamped
    /// readings: flat while the slope is inside ±`deadbandPerHour`, `nil`
    /// when the readings span less than 15 minutes — too little signal for
    /// a slope (that also covers empty and single-reading input).
    ///
    /// A fitted slope with a real deadband replaces comparing the newest
    /// reading against the window mean with `Int`-truncated equality, which
    /// flagged a 0.02-unit difference as a trend when it straddled an
    /// integer but called a 0.98-unit move flat — and used the same "1
    /// unit" for every kind, from AQHI's 1–11 scale to VOC's 0–1500.
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

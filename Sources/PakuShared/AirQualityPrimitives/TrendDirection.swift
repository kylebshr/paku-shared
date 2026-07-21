import Foundation

/// Which way a reading has been heading. Shared by the app's widget/watch
/// arrows and the server's Live Activity push job so both classify the same
/// readings the same way.
public enum TrendDirection: Equatable, Hashable, Codable, Sendable {
    case up
    case flat
    case down
}

extension TrendDirection {
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

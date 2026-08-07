public enum AverageTimePeriod: Int, Codable, CaseIterable, Sendable {
    case now = 0
    case tenMinutes = 1
    case halfHour = 2
    case oneHour = 3

    /// Decodes unrecognized raw values as `.oneHour` instead of failing.
    ///
    /// Raw values 4, 5 and 6 used to mean the six-hour, 24-hour and one-week
    /// averages. Those cases are gone, but the numbers are still out in the
    /// wild: persisted in user defaults on devices, and sent by older app
    /// versions in the subscription and alert payloads the server decodes. A
    /// strict raw-value decode would throw on them and turn those requests
    /// into errors, so anything unrecognized collapses to the longest window
    /// still supported. Consumers migrate their stored rows separately.
    ///
    /// `init?(rawValue:)` is deliberately left strict — it still returns nil
    /// for 4, 5 and 6 — so only decoding is lenient.
    public init(from decoder: any Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        self = AverageTimePeriod(rawValue: rawValue) ?? .oneHour
    }
}

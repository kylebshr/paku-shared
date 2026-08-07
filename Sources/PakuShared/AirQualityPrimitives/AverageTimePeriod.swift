public enum AverageTimePeriod: Int, Codable, CaseIterable, Sendable {
    case now = 0
    case tenMinutes = 1
    case halfHour = 2
    case oneHour = 3
}

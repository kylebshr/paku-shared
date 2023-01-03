enum AverageTimePeriod: Int, Codable, CaseIterable {
    case now = 0
    case tenMinutes = 1
    case halfHour = 2
    case oneHour = 3
    case sixHours = 4
    case day = 5
    case week = 6
}

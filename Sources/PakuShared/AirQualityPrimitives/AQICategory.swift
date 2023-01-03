public enum AQICategory: Double, CaseIterable {
    case good                           = 0
    case moderate                       = 51
    case unhealthyForSensitiveGroups    = 101
    case unhealthy                      = 151
    case veryUnhealthy                  = 201
    case hazardous                      = 301

    public init(aqi: Double) {
        switch aqi {
        case ...50: self = .good
        case ...100: self = .moderate
        case ...150: self = .unhealthyForSensitiveGroups
        case ...200: self = .unhealthy
        case ...300: self = .veryUnhealthy
        default: self = .hazardous
        }
    }

    public var description: String {
        switch self {
        case .hazardous:
            return "Hazardous"
        case .veryUnhealthy:
            return "Very Unhealthy"
        case .unhealthy:
            return "Unhealthy"
        case .unhealthyForSensitiveGroups:
            return "Unhealthy for Sensitive Groups"
        case .moderate:
            return "Moderate"
        case .good:
            return "Good"
        }
    }
}

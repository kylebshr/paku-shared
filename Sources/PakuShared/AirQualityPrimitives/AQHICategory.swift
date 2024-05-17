public enum AQHICategory: Int, CaseIterable {
    case lowRisk        = 0
    case moderateRisk   = 4
    case highRisk       = 7
    case veryHighRisk   = 11

    public init(aqhi: Double) {
        switch aqhi {
        case ...3: self = .lowRisk
        case ...6: self = .moderateRisk
        case ...10: self = .highRisk
        default: self = .veryHighRisk
        }
    }

    public var description: String {
        switch self {
        case .lowRisk:
            "Low Risk"
        case .moderateRisk:
            "Moderate Risk"
        case .highRisk:
            "High Risk"
        case .veryHighRisk:
            "Very High Risk"
        }
    }
}

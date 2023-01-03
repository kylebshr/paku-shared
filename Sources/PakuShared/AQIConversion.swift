public enum AQIConversion: Int, Codable, CaseIterable {
    case none = 0
    /// Do not use 1; it may be used on an older device for AQAndU, which has been removed
    // case AQAndU = 1
    case EPA = 2
}

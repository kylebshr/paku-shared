import Foundation

/// Which APNs environment a token was issued under. The client reports it at
/// registration (DEBUG builds get development tokens) and every send picks
/// the matching container.
public enum LiveActivityEnvironment: String, Codable, Sendable {
    case development
    case production
}

import Foundation

/// Custom payload carried on alert pushes alongside `aps`. `sensorID` lets
/// the app deep-link to the sensor the alert is about. The templates are
/// copies of the rendered alert strings with a single `%@` in place of the
/// sensor's name; the notification service extension re-renders them with
/// its local nickname for the sensor when one exists, and otherwise the
/// `aps` strings (which carry the PurpleAir name) stand as sent. Templates
/// must contain exactly one `%@` and no other `%` — the client refuses to
/// render anything else.
public struct APNSensorNotification: Codable, Sendable {
    public static let sensorNamePlaceholder = "%@"

    public var sensorID: Int?
    public var titleTemplate: String?
    public var bodyTemplate: String?

    enum CodingKeys: String, CodingKey {
        case sensorID = "sensor_id"
        case titleTemplate = "title_template"
        case bodyTemplate = "body_template"
    }

    public init(sensorID: Int?, titleTemplate: String? = nil, bodyTemplate: String? = nil) {
        self.sensorID = sensorID
        self.titleTemplate = titleTemplate
        self.bodyTemplate = bodyTemplate
    }

    public init?(userInfo: [AnyHashable: Any]) {
        let sensorID = userInfo[CodingKeys.sensorID.rawValue] as? Int
        let titleTemplate = userInfo[CodingKeys.titleTemplate.rawValue] as? String
        let bodyTemplate = userInfo[CodingKeys.bodyTemplate.rawValue] as? String

        guard sensorID != nil || titleTemplate != nil || bodyTemplate != nil else {
            return nil
        }

        self.init(sensorID: sensorID, titleTemplate: titleTemplate, bodyTemplate: bodyTemplate)
    }

    public func title(sensorName: String) -> String? {
        titleTemplate.flatMap { Self.fill($0, sensorName: sensorName) }
    }

    public func body(sensorName: String) -> String? {
        bodyTemplate.flatMap { Self.fill($0, sensorName: sensorName) }
    }

    private static func fill(_ template: String, sensorName: String) -> String? {
        guard template.components(separatedBy: "%").count == 2, template.contains("%@") else {
            return nil
        }

        return String(format: template, sensorName)
    }
}

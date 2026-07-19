import Foundation

/// `PUT /live-activity-config` — upsert (keyed by `deviceID`) the device's
/// push-to-start configuration.
public struct UpdateLiveActivityConfigRequest: Codable, Sendable {
    public var userID: UUID
    public var deviceID: UUID

    /// Hex push-to-start token; nil clears it (user disabled or token unknown).
    public var pushToStartToken: String?

    public var environment: LiveActivityEnvironment
    public var enabled: Bool

    /// AQI threshold, same semantics as `SensorNotificationRequest.threshold`.
    public var threshold: Int

    public var conversion: AQIConversion

    /// The device's current nearest sensor, if known.
    public var sensorID: Int?

    /// Meters to the sensor.
    public var distance: Double?

    public init(
        userID: UUID,
        deviceID: UUID,
        pushToStartToken: String?,
        environment: LiveActivityEnvironment,
        enabled: Bool,
        threshold: Int,
        conversion: AQIConversion,
        sensorID: Int?,
        distance: Double?
    ) {
        self.userID = userID
        self.deviceID = deviceID
        self.pushToStartToken = pushToStartToken
        self.environment = environment
        self.enabled = enabled
        self.threshold = threshold
        self.conversion = conversion
        self.sensorID = sensorID
        self.distance = distance
    }
}

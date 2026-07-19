import Foundation

/// `POST /live-activities` — register a Live Activity, or refresh it after a
/// push-token rotation.
public struct RegisterLiveActivityRequest: Codable, Sendable {
    public var userID: UUID
    public var deviceID: UUID

    /// ActivityKit `Activity.id` — the upsert key, stable across rotations.
    public var activityID: String

    /// The activity's update token, hex-encoded.
    public var pushToken: String

    public var environment: LiveActivityEnvironment

    /// Omitted when the device doesn't know its sensor yet (e.g. a
    /// push-to-start pickup in the background).
    public var sensorID: Int?

    /// Meters to the sensor.
    public var distance: Double?

    public var conversion: AQIConversion

    public init(
        userID: UUID,
        deviceID: UUID,
        activityID: String,
        pushToken: String,
        environment: LiveActivityEnvironment,
        sensorID: Int?,
        distance: Double?,
        conversion: AQIConversion
    ) {
        self.userID = userID
        self.deviceID = deviceID
        self.activityID = activityID
        self.pushToken = pushToken
        self.environment = environment
        self.sensorID = sensorID
        self.distance = distance
        self.conversion = conversion
    }
}

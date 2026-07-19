import Foundation

/// `PUT /live-activities/anchor` — cheap sensor re-anchor while an activity
/// runs: updates the sensor/distance on all of the device's activities and
/// its push-to-start config.
public struct UpdateLiveActivityAnchorRequest: Codable, Sendable {
    public var userID: UUID
    public var deviceID: UUID
    public var sensorID: Int

    /// Meters to the sensor.
    public var distance: Double?

    public init(
        userID: UUID,
        deviceID: UUID,
        sensorID: Int,
        distance: Double?
    ) {
        self.userID = userID
        self.deviceID = deviceID
        self.sensorID = sensorID
        self.distance = distance
    }
}

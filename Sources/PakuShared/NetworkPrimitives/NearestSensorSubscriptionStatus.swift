import Foundation

public struct NearestSensorSubscriptionStatus: Codable, Sendable {
    public var subscription: NearestSensorSubscriptionResponse?

    init(subscription: NearestSensorSubscriptionResponse?) {
        self.subscription = subscription
    }
}

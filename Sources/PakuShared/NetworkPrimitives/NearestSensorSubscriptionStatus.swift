import Foundation

public struct NearestSensorSubscriptionStatus: Codable, Sendable {
    public var subscription: NearestSensorSubscriptionResponse?

    public init(subscription: NearestSensorSubscriptionResponse?) {
        self.subscription = subscription
    }
}

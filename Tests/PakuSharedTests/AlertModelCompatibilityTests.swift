import XCTest
@testable import PakuShared

// `isCritical` was added after these payloads started being cached on
// device and stored server-side — old JSON without the key must keep
// decoding, and `nil` means false.
final class AlertModelCompatibilityTests: XCTestCase {

    func testSensorNotificationRequestDecodesWithoutIsCritical() throws {
        let json = """
        {"userID":"\(UUID())","sensorID":1,"threshold":100,"conversion":2,\
        "averagingPeriod":1,"sendBelowThreshold":false}
        """

        let request = try JSONDecoder().decode(
            SensorNotificationRequest.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(request.isCritical)
    }

    func testSensorNotificationResponseDecodesWithoutIsCritical() throws {
        let json = """
        {"averagingPeriod":1,"conversion":2,"id":"\(UUID())",\
        "isNearestSensor":false,"sendBelowThreshold":false,"sensorID":1,\
        "sensorName":"Test","threshold":100}
        """

        let response = try JSONDecoder().decode(
            SensorNotificationResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(response.isCritical)
    }

    func testCreateNearestSensorSubscriptionRequestDecodesWithoutIsCritical() throws {
        let json = """
        {"userID":"\(UUID())","deviceID":"\(UUID())","threshold":100,\
        "conversion":2,"averagingPeriod":1,"sendBelowThreshold":true}
        """

        let request = try JSONDecoder().decode(
            CreateNearestSensorSubscriptionRequest.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(request.isCritical)
    }

    func testNearestSensorSubscriptionResponseDecodesWithoutIsCritical() throws {
        let json = """
        {"deviceID":"\(UUID())","threshold":100,"conversion":2,\
        "averagingPeriod":1,"sendBelowThreshold":true,"lastReportedAt":0}
        """

        let response = try JSONDecoder().decode(
            NearestSensorSubscriptionResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertNil(response.isCritical)
    }

    func testIsCriticalRoundTrips() throws {
        let request = SensorNotificationRequest(
            userID: UUID(),
            sensorID: 1,
            threshold: 100,
            conversion: .none,
            averagingPeriod: .tenMinutes,
            sendBelowThreshold: false,
            isCritical: true
        )

        let decoded = try JSONDecoder().decode(
            SensorNotificationRequest.self,
            from: JSONEncoder().encode(request)
        )

        XCTAssertEqual(decoded.isCritical, true)
    }
}

import Foundation
import Testing
@testable import PakuShared

@Suite("APNSensorNotification wire format")
struct APNSensorNotificationTests {

    @Test("Encodes with snake_case keys")
    func encodesWithSnakeCaseKeys() throws {
        let payload = APNSensorNotification(
            sensorID: 42,
            titleTemplate: "Alerts Enabled for %@",
            bodyTemplate: "AQI at %@ is now 151 (real-time)"
        )

        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["sensor_id"] as? Int == 42)
        #expect(json?["title_template"] as? String == "Alerts Enabled for %@")
        #expect(json?["body_template"] as? String == "AQI at %@ is now 151 (real-time)")
    }

    @Test("Round-trips through Codable")
    func roundTrips() throws {
        let payload = APNSensorNotification(sensorID: 42, bodyTemplate: "AQI at %@ is now 151")
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(APNSensorNotification.self, from: data)

        #expect(decoded.sensorID == 42)
        #expect(decoded.titleTemplate == nil)
        #expect(decoded.bodyTemplate == "AQI at %@ is now 151")
    }

    @Test("Decodes from notification userInfo")
    func decodesFromUserInfo() {
        let payload = APNSensorNotification(userInfo: [
            "aps": ["alert": ["title": "Sensor Online"]],
            "sensor_id": 42,
            "body_template": "%@ is back online. Alerts have resumed.",
        ])

        #expect(payload?.sensorID == 42)
        #expect(payload?.titleTemplate == nil)
        #expect(payload?.bodyTemplate == "%@ is back online. Alerts have resumed.")
    }

    @Test("userInfo without any payload keys is not a payload")
    func userInfoWithoutPayloadKeys() {
        #expect(APNSensorNotification(userInfo: ["aps": ["alert": ["title": "Hi"]]]) == nil)
    }

    @Suite("Template rendering")
    struct TemplateRenderingTests {
        @Test("Fills the sensor name into both templates")
        func fillsTemplates() {
            let payload = APNSensorNotification(
                sensorID: 42,
                titleTemplate: "Alerts Enabled for %@",
                bodyTemplate: "%@ is back online. Alerts have resumed."
            )

            #expect(payload.title(sensorName: "Backyard") == "Alerts Enabled for Backyard")
            #expect(payload.body(sensorName: "Backyard") == "Backyard is back online. Alerts have resumed.")
        }

        @Test("Missing templates render to nothing")
        func missingTemplates() {
            let payload = APNSensorNotification(sensorID: 42)

            #expect(payload.title(sensorName: "Backyard") == nil)
            #expect(payload.body(sensorName: "Backyard") == nil)
        }

        /// The client formats templates with `String(format:)`, so anything
        /// but exactly one `%@` must be refused rather than rendered.
        @Test("Refuses malformed templates", arguments: [
            "AQI is 151",
            "Humidity is 45% at %@",
            "%d readings at %@",
            "%@ and %@",
            "100%% at %@",
        ])
        func refusesMalformedTemplates(template: String) {
            let payload = APNSensorNotification(sensorID: 42, titleTemplate: template, bodyTemplate: template)

            #expect(payload.title(sensorName: "Backyard") == nil)
            #expect(payload.body(sensorName: "Backyard") == nil)
        }
    }
}

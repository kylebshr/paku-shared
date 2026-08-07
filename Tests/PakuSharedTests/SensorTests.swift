import XCTest
@testable import PakuShared

final class SensorTests: XCTestCase {
    private func makeResponse(channelFlags: ChannelFlags?) -> SensorResponse {
        SensorResponse(
            id: 1,
            name: "Sensor",
            latitude: 37.0,
            longitude: -122.0,
            locationType: .outdoors,
            lastSeen: Date(timeIntervalSince1970: 1_000_000),
            altitude: nil,
            humidity: nil,
            confidence: nil,
            temperature: nil,
            pm2_5: 10,
            pm2_5_cf_1: 10,
            pm2_5_10minute: 10,
            pm2_5_30minute: 10,
            pm2_5_60minute: 10,
            pm1_0: nil,
            pm10_0: nil,
            voc: nil,
            channelFlags: channelFlags
        )
    }

    func test_legacyPeriodsFallBackToTheOneHourAverage() throws {
        let sensor = try Sensor(response: SensorResponse(
            id: 1,
            name: "Sensor",
            latitude: 37.0,
            longitude: -122.0,
            locationType: .outdoors,
            lastSeen: Date(timeIntervalSince1970: 1_000_000),
            pm2_5: 10,
            pm2_5_cf_1: 10,
            pm2_5_10minute: 20,
            pm2_5_30minute: 30,
            pm2_5_60minute: 40
        ))

        XCTAssertEqual(sensor.pm2_5(for: .sixHours), 40)
        XCTAssertEqual(sensor.pm2_5(for: .day), 40)
        XCTAssertEqual(sensor.pm2_5(for: .week), 40)
    }

    func test_channelFlagsCarriesThroughFromResponse() throws {
        let sensor = try Sensor(response: makeResponse(channelFlags: .bDowngraded))
        XCTAssertEqual(sensor.channelFlags, .bDowngraded)
    }

    func test_decodingWithoutChannelFlagsIsNil() throws {
        // Sensor values encoded by app versions that predate the field must
        // keep decoding.
        var data = try JSONEncoder().encode(Sensor(response: makeResponse(channelFlags: .normal)))
        var json = try XCTUnwrap(String(data: data, encoding: .utf8))
        json = json.replacingOccurrences(of: "\"channelFlags\":0,", with: "")
        json = json.replacingOccurrences(of: ",\"channelFlags\":0", with: "")
        data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertFalse(json.contains("channelFlags"))
        let decoded = try JSONDecoder().decode(Sensor.self, from: data)
        XCTAssertNil(decoded.channelFlags)
    }
}

import XCTest
@testable import PakuShared

final class SensorResponseTests: XCTestCase {
    private func makeSensor(channelFlags: ChannelFlags?) -> SensorResponse {
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
            pm2_5_10minute: nil,
            pm2_5_30minute: nil,
            pm2_5_60minute: nil,
            pm2_5_6hour: nil,
            pm2_5_24hour: nil,
            pm2_5_1week: nil,
            pm1_0: nil,
            pm10_0: nil,
            voc: nil,
            channelFlags: channelFlags
        )
    }

    func test_channelFlagsRoundTrips() throws {
        let data = try JSONEncoder().encode(makeSensor(channelFlags: .aDowngraded))
        let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)

        XCTAssertEqual(decoded.channelFlags, .aDowngraded)
        XCTAssertTrue(decoded.channelFlags?.hasDowngradedChannel == true)
    }

    func test_decodingWithoutChannelFlagsIsNil() throws {
        // JSON from servers that predate the field must keep decoding.
        var data = try JSONEncoder().encode(makeSensor(channelFlags: .normal))
        var json = try XCTUnwrap(String(data: data, encoding: .utf8))
        json = json.replacingOccurrences(of: "\"channelFlags\":0,", with: "")
        json = json.replacingOccurrences(of: ",\"channelFlags\":0", with: "")
        data = try XCTUnwrap(json.data(using: .utf8))

        XCTAssertFalse(json.contains("channelFlags"))
        let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)
        XCTAssertNil(decoded.channelFlags)
    }

    func test_hasDowngradedChannel() {
        XCTAssertFalse(ChannelFlags.normal.hasDowngradedChannel)
        XCTAssertTrue(ChannelFlags.aDowngraded.hasDowngradedChannel)
        XCTAssertTrue(ChannelFlags.bDowngraded.hasDowngradedChannel)
        XCTAssertTrue(ChannelFlags.bothDowngraded.hasDowngradedChannel)
    }
}

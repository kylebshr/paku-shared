import Foundation
import Testing
@testable import PakuShared

@Suite("SensorResponse wire format")
struct SensorResponseTests {

    @Suite("channelFlags")
    struct ChannelFlagsTests {
        @Test("Round-trips every case", arguments: [
            ChannelFlags.normal, .aDowngraded, .bDowngraded, .bothDowngraded,
        ])
        func roundTrips(flags: ChannelFlags) throws {
            let data = try JSONEncoder().encode(SensorResponse.stub(channelFlags: flags))
            let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)

            #expect(decoded.channelFlags == flags)
        }

        /// JSON from servers that predate the field must keep decoding.
        @Test("Decoding without the key yields nil")
        func decodingWithoutChannelFlagsIsNil() throws {
            let data = try encoded(SensorResponse.stub(channelFlags: .normal), omitting: "channelFlags")
            let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)

            #expect(decoded.channelFlags == nil)
        }

        @Test("Only .normal reads as healthy", arguments: [
            (flags: ChannelFlags.normal, isDowngraded: false),
            (flags: .aDowngraded, isDowngraded: true),
            (flags: .bDowngraded, isDowngraded: true),
            (flags: .bothDowngraded, isDowngraded: true),
        ])
        func hasDowngradedChannel(flags: ChannelFlags, isDowngraded: Bool) {
            #expect(flags.hasDowngradedChannel == isDowngraded)
        }
    }

    @Suite("Legacy long-window averages")
    struct LegacyAverages {
        /// Released app versions drop any sensor whose long-window averages
        /// decode as nil, so the keys must stay in the wire format.
        @Test("Encoding still writes them as zero", arguments: [
            "pm2_5_6hour", "pm2_5_24hour", "pm2_5_1week",
        ])
        func encodingWritesLegacyAverageAsZero(key: String) throws {
            let data = try JSONEncoder().encode(SensorResponse.stub())
            let json = try #require(String(data: data, encoding: .utf8))

            #expect(json.contains("\"\(key)\":0"))
        }

        @Test("Decoding without them succeeds")
        func decodingWithoutLegacyAveragesSucceeds() throws {
            let json = """
            {
                "id": 1,
                "name": "Sensor",
                "latitude": 37.0,
                "longitude": -122.0,
                "locationType": 0,
                "lastSeen": 1000000,
                "pm2_5": 10,
                "pm2_5_cf_1": 10,
                "pm2_5_10minute": 10,
                "pm2_5_30minute": 10,
                "pm2_5_60minute": 10
            }
            """
            let data = try #require(json.data(using: .utf8))
            let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)

            #expect(decoded.id == 1)
            #expect(decoded.pm2_5_60minute == 10)
        }
    }

    @Test("Every field survives a Codable round trip")
    func roundTripsThroughCodable() throws {
        let sensor = SensorResponse.stub(channelFlags: .bothDowngraded)
        let data = try JSONEncoder().encode(sensor)
        let decoded = try JSONDecoder().decode(SensorResponse.self, from: data)

        #expect(decoded.id == sensor.id)
        #expect(decoded.name == sensor.name)
        #expect(decoded.latitude == sensor.latitude)
        #expect(decoded.longitude == sensor.longitude)
        #expect(decoded.locationType == sensor.locationType)
        #expect(decoded.lastSeen == sensor.lastSeen)
        #expect(decoded.pm2_5 == sensor.pm2_5)
        #expect(decoded.pm2_5_cf_1 == sensor.pm2_5_cf_1)
        #expect(decoded.pm2_5_60minute == nil)
        #expect(decoded.channelFlags == .bothDowngraded)
    }
}

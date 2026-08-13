import Foundation
import Testing
@testable import PakuShared

@Suite("Sensor")
struct SensorTests {
    @Test("Each period reads its own average", arguments: [
        (period: AverageTimePeriod.now, expected: 10.0),
        (period: .tenMinutes, expected: 20.0),
        (period: .halfHour, expected: 30.0),
        (period: .oneHour, expected: 40.0),
    ])
    func eachPeriodReadsItsOwnAverage(period: AverageTimePeriod, expected: Double) throws {
        let sensor = try Sensor.stub(
            pm2_5: 10, pm2_5_10minute: 20, pm2_5_30minute: 30, pm2_5_60minute: 40
        )

        #expect(sensor.pm2_5(for: period) == expected)
    }

    @Test("channelFlags carries through from the response", arguments: [
        ChannelFlags.normal, .aDowngraded, .bDowngraded, .bothDowngraded,
    ])
    func channelFlagsCarriesThroughFromResponse(flags: ChannelFlags) throws {
        let sensor = try Sensor.stub(channelFlags: flags)
        #expect(sensor.channelFlags == flags)
    }

    /// Sensor values encoded by app versions that predate the field must
    /// keep decoding.
    @Test("Decoding without channelFlags yields nil")
    func decodingWithoutChannelFlagsIsNil() throws {
        let data = try encoded(Sensor.stub(channelFlags: .normal), omitting: "channelFlags")

        let decoded = try JSONDecoder().decode(Sensor.self, from: data)
        #expect(decoded.channelFlags == nil)
    }
}

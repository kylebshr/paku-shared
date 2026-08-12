import Foundation
import Testing
@testable import PakuShared

@Suite("AQI scales")
struct AQITests {
    /// One row of an AQI table: a raw reading and what it should scale to.
    struct Reading: Sendable, CustomTestStringConvertible {
        let pm2_5: Double
        let humidity: Int
        let expected: Double

        init(_ pm2_5: Double, humidity: Int, expected: Double) {
            self.pm2_5 = pm2_5
            self.humidity = humidity
            self.expected = expected
        }

        var testDescription: String {
            "\(pm2_5) µg/m³ at \(humidity)% RH → \(expected)"
        }
    }

    @Test("AQHI", arguments: [
        Reading(168, humidity: 40, expected: 8),
        Reading(45, humidity: 54, expected: 2),
        Reading(39, humidity: 37, expected: 2),
        Reading(0, humidity: 37, expected: 1),
    ])
    func aqhi(reading: Reading) {
        let value = AQI.aqhi(
            for: reading.pm2_5, humidity: reading.humidity, conversion: .none, location: .outdoors
        )
        #expect(value.rounded() == reading.expected)
    }

    @Test("AQHI+", arguments: [
        Reading(168, humidity: 40, expected: 17),
        Reading(42, humidity: 54, expected: 5),
        Reading(39, humidity: 37, expected: 4),
        Reading(0, humidity: 37, expected: 1),
    ])
    func aqhiPlus(reading: Reading) {
        let value = AQI.aqhiPlus(
            for: reading.pm2_5, humidity: reading.humidity, conversion: .none, location: .outdoors
        )
        #expect(value.rounded() == reading.expected)
    }

    /// Without a conversion the scale is raw PM2.5, so indoors and outdoors
    /// must land on the same number.
    @Test("Unconverted AQI ignores location", arguments: [
        Reading(168, humidity: 40, expected: 243),
        Reading(45, humidity: 54, expected: 124),
        Reading(39, humidity: 37, expected: 110),
        Reading(0, humidity: 37, expected: 0),
    ], [LocationType.outdoors, .indoors])
    func unconvertedAQI(reading: Reading, location: LocationType) {
        let value = AQI.value(
            for: reading.pm2_5, humidity: reading.humidity, conversion: .none, location: location
        )
        #expect(value.rounded() == reading.expected)
    }

    @Test("EPA-converted AQI, outdoors", arguments: [
        Reading(168, humidity: 40, expected: 210),
        Reading(45, humidity: 54, expected: 96),
        Reading(39, humidity: 37, expected: 85),
        Reading(0, humidity: 37, expected: 14),
    ])
    func epaAQIOutdoors(reading: Reading) {
        let value = AQI.value(
            for: reading.pm2_5, humidity: reading.humidity, conversion: .EPA, location: .outdoors
        )
        #expect(value.rounded() == reading.expected)
    }

    /// The EPA correction is tuned for outdoor woodsmoke, so indoors reads
    /// lower than outdoors for the same particle count.
    @Test("EPA-converted AQI, indoors", arguments: [
        Reading(168, humidity: 40, expected: 175),
        Reading(45, humidity: 54, expected: 80),
        Reading(39, humidity: 37, expected: 77),
        Reading(0, humidity: 37, expected: 14),
    ])
    func epaAQIIndoors(reading: Reading) {
        let value = AQI.value(
            for: reading.pm2_5, humidity: reading.humidity, conversion: .EPA, location: .indoors
        )
        #expect(value.rounded() == reading.expected)
    }
}

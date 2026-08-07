import XCTest
@testable import PakuShared

final class AverageTimePeriodTests: XCTestCase {
    private func decode(_ json: String) throws -> AverageTimePeriod {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(AverageTimePeriod.self, from: data)
    }

    func test_supportedRawValuesRoundTrip() throws {
        for period in AverageTimePeriod.allCases {
            let data = try JSONEncoder().encode(period)
            let json = try XCTUnwrap(String(data: data, encoding: .utf8))

            XCTAssertEqual(json, String(period.rawValue))
            XCTAssertEqual(try decode(json), period)
        }
    }

    func test_supportedRawValuesDecodeExactly() throws {
        XCTAssertEqual(try decode("0"), .now)
        XCTAssertEqual(try decode("1"), .tenMinutes)
        XCTAssertEqual(try decode("2"), .halfHour)
        XCTAssertEqual(try decode("3"), .oneHour)
    }

    func test_removedLongWindowRawValuesDecodeToOneHour() throws {
        // 4, 5 and 6 were the six-hour, 24-hour and one-week periods. Devices
        // and older app versions still send them.
        XCTAssertEqual(try decode("4"), .oneHour)
        XCTAssertEqual(try decode("5"), .oneHour)
        XCTAssertEqual(try decode("6"), .oneHour)
    }

    func test_unknownRawValuesDecodeToOneHour() throws {
        XCTAssertEqual(try decode("99"), .oneHour)
        XCTAssertEqual(try decode("-1"), .oneHour)
    }

    func test_nonIntegerValueStillFailsToDecode() {
        // Leniency covers unrecognized periods, not malformed payloads.
        XCTAssertThrowsError(try decode("\"sixHours\""))
    }

    func test_rawValueInitializerStaysStrict() {
        XCTAssertNil(AverageTimePeriod(rawValue: 4))
        XCTAssertNil(AverageTimePeriod(rawValue: 5))
        XCTAssertNil(AverageTimePeriod(rawValue: 6))
        XCTAssertEqual(AverageTimePeriod(rawValue: 3), .oneHour)
    }

    func test_allCasesAreTheFourSupportedPeriods() {
        XCTAssertEqual(AverageTimePeriod.allCases, [.now, .tenMinutes, .halfHour, .oneHour])
    }

    func test_legacyPeriodInAnAlertPayloadDecodes() throws {
        // The shape the server actually sees: a request body from an older app
        // version whose stored averaging period is the removed one-week case.
        let json = """
        {
            "sensorID": 12345,
            "averagingPeriod": 6,
            "threshold": 100
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(LegacyAlertPayload.self, from: data)

        XCTAssertEqual(decoded.averagingPeriod, .oneHour)
    }

    private struct LegacyAlertPayload: Decodable {
        let sensorID: Int
        let averagingPeriod: AverageTimePeriod
        let threshold: Int
    }
}

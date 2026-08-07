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

    func test_rawValueInitializer() {
        XCTAssertEqual(AverageTimePeriod(rawValue: 0), .now)
        XCTAssertEqual(AverageTimePeriod(rawValue: 3), .oneHour)
        XCTAssertNil(AverageTimePeriod(rawValue: 4))
    }

    func test_allCasesAreTheFourSupportedPeriods() {
        XCTAssertEqual(AverageTimePeriod.allCases, [.now, .tenMinutes, .halfHour, .oneHour])
    }
}

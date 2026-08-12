import Foundation
import Testing
@testable import PakuShared

@Suite("AverageTimePeriod")
struct AverageTimePeriodTests {
    private func decode(_ json: String) throws -> AverageTimePeriod {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder().decode(AverageTimePeriod.self, from: data)
    }

    @Test("Every case survives a Codable round trip", arguments: AverageTimePeriod.allCases)
    func roundTrips(period: AverageTimePeriod) throws {
        let data = try JSONEncoder().encode(period)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json == String(period.rawValue))
        #expect(try decode(json) == period)
    }

    /// The raw values are the wire format — pinned so a reordering of the
    /// cases can't silently renumber them.
    @Test("Raw values decode to exactly one case", arguments: [
        (json: "0", period: AverageTimePeriod.now),
        (json: "1", period: .tenMinutes),
        (json: "2", period: .halfHour),
        (json: "3", period: .oneHour),
    ])
    func decodesExactly(json: String, period: AverageTimePeriod) throws {
        #expect(try decode(json) == period)
        #expect(AverageTimePeriod(rawValue: period.rawValue) == period)
    }

    @Test("Unknown raw values are rejected")
    func rejectsUnknownRawValue() {
        #expect(AverageTimePeriod(rawValue: 4) == nil)
        #expect(AverageTimePeriod(rawValue: -1) == nil)
    }

    @Test("allCases is the four supported periods, in order")
    func allCasesAreTheFourSupportedPeriods() {
        #expect(AverageTimePeriod.allCases == [.now, .tenMinutes, .halfHour, .oneHour])
    }
}

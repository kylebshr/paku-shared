import XCTest
@testable import PakuShared

final class TrendDirectionTests: XCTestCase {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// Half-hourly readings ending an hour after `start`.
    private func samples(_ values: [Double]) -> [(date: Date, value: Double)] {
        values.enumerated().map { index, value in
            (date: start.addingTimeInterval(Double(index) * 30 * 60), value: value)
        }
    }

    func testRisingSlopeIsUp() {
        XCTAssertEqual(.up, TrendDirection.of(samples: samples([10, 20, 30]), deadbandPerHour: 4))
    }

    func testFallingSlopeIsDown() {
        XCTAssertEqual(.down, TrendDirection.of(samples: samples([30, 20, 10]), deadbandPerHour: 4))
    }

    func testDriftInsideDeadbandIsFlat() {
        // Rises 2 units over the hour — inside a 4-per-hour deadband.
        XCTAssertEqual(.flat, TrendDirection.of(samples: samples([10, 11, 12]), deadbandPerHour: 4))
    }

    /// The old rule compared `Int`-truncated values, so a 0.2-unit jiggle
    /// straddling an integer (45.9 → 46.1) rendered an arrow.
    func testIntegerBoundaryJitterIsFlat() {
        XCTAssertEqual(.flat, TrendDirection.of(samples: samples([45.9, 46.1, 45.9]), deadbandPerHour: 4))
    }

    /// The old rule truncated a near-full-unit move (45.1 → 45.9) to
    /// "equal", hiding a genuine climb when it repeats across hours — the
    /// fitted slope only cares about the actual rate.
    func testSteadyClimbBeatsTruncation() {
        XCTAssertEqual(.up, TrendDirection.of(samples: samples([45.1, 47.6, 50.1]), deadbandPerHour: 4))
    }

    func testNoiseAroundLevelMeanIsFlat() {
        XCTAssertEqual(
            .flat,
            TrendDirection.of(samples: samples([12, 16, 11, 15, 12]), deadbandPerHour: 4)
        )
    }

    func testTooFewOrTooCloseSamplesIsNil() {
        XCTAssertNil(TrendDirection.of(samples: [], deadbandPerHour: 4))
        XCTAssertNil(TrendDirection.of(samples: samples([12]), deadbandPerHour: 4))

        // Two readings four minutes apart: spans less than 15 minutes.
        let close = [
            (date: start, value: 10.0),
            (date: start.addingTimeInterval(4 * 60), value: 50.0),
        ]
        XCTAssertNil(TrendDirection.of(samples: close, deadbandPerHour: 4))
    }

    func testUnsortedSamplesMatchSorted() {
        let sorted = samples([10, 20, 30])
        XCTAssertEqual(
            TrendDirection.of(samples: sorted, deadbandPerHour: 4),
            TrendDirection.of(samples: sorted.reversed(), deadbandPerHour: 4)
        )
    }

    /// The deadband is per-kind precisely because scales differ: the same
    /// climb that's a trend on AQHI's 1–11 scale is noise on VOC's 0–1500.
    func testDeadbandScalesWithKind() {
        let climb = samples([10, 11, 12])
        XCTAssertEqual(.up, TrendDirection.of(samples: climb, deadbandPerHour: 0.5))
        XCTAssertEqual(.flat, TrendDirection.of(samples: climb, deadbandPerHour: 30))
    }
}

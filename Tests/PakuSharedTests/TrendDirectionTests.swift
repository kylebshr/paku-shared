import Foundation
import Testing
@testable import PakuShared

private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

/// Half-hourly readings starting at `start`.
private func samples(_ values: [Double]) -> [(date: Date, value: Double)] {
    values.enumerated().map { index, value in
        (date: start.addingTimeInterval(Double(index) * 30 * 60), value: value)
    }
}

@Suite("TrendDirection")
struct TrendDirectionTests {

    @Suite("Slope over samples")
    struct Slope {
        /// A series of half-hourly readings and the arrow it should produce.
        struct Case: Sendable, CustomTestStringConvertible {
            let values: [Double]
            let deadbandPerHour: Double
            let expected: TrendDirection
            let note: String

            var testDescription: String { note }
        }

        @Test("Classifies against the deadband", arguments: [
            Case(values: [10, 20, 30], deadbandPerHour: 4, expected: .up,
                 note: "a rising slope is up"),
            Case(values: [30, 20, 10], deadbandPerHour: 4, expected: .down,
                 note: "a falling slope is down"),
            Case(values: [10, 11, 12], deadbandPerHour: 4, expected: .flat,
                 note: "2 units over the hour is inside a 4-per-hour deadband"),
            Case(values: [45.9, 46.1, 45.9], deadbandPerHour: 4, expected: .flat,
                 note: "a 0.2-unit jiggle straddling an integer draws no arrow"),
            Case(values: [45.1, 47.6, 50.1], deadbandPerHour: 4, expected: .up,
                 note: "a steady sub-unit-per-sample climb is still a climb"),
            Case(values: [12, 16, 11, 15, 12], deadbandPerHour: 4, expected: .flat,
                 note: "noise around a level mean is flat"),
            Case(values: [10, 11, 12], deadbandPerHour: 0.5, expected: .up,
                 note: "the same climb is a trend on AQHI's 1–11 scale"),
            Case(values: [10, 11, 12], deadbandPerHour: 30, expected: .flat,
                 note: "…and noise on VOC's 0–1500 scale"),
        ])
        func classifies(testCase: Case) {
            let direction = TrendDirection.of(
                samples: samples(testCase.values), deadbandPerHour: testCase.deadbandPerHour
            )
            #expect(direction == testCase.expected)
        }

        @Test("Too few or too closely spaced samples yield no trend")
        func tooFewOrTooCloseSamplesIsNil() {
            #expect(TrendDirection.of(samples: [], deadbandPerHour: 4) == nil)
            #expect(TrendDirection.of(samples: samples([12]), deadbandPerHour: 4) == nil)

            // Two readings four minutes apart: spans less than 15 minutes.
            let close = [
                (date: start, value: 10.0),
                (date: start.addingTimeInterval(4 * 60), value: 50.0),
            ]
            #expect(TrendDirection.of(samples: close, deadbandPerHour: 4) == nil)
        }

        @Test("Sample order does not matter")
        func unsortedSamplesMatchSorted() {
            let sorted = samples([10, 20, 30])
            #expect(
                TrendDirection.of(samples: sorted, deadbandPerHour: 4)
                    == TrendDirection.of(samples: sorted.reversed(), deadbandPerHour: 4)
            )
        }
    }

    @Suite("Fast-vs-slow crossover")
    struct Crossover {
        /// A fast and slow average, and the arrow their gap should produce.
        struct Case: Sendable, CustomTestStringConvertible {
            let fast: Double
            let slow: Double
            let deadband: Double
            let expected: TrendDirection
            let note: String

            var testDescription: String { note }
        }

        @Test("Classifies against the deadband", arguments: [
            Case(fast: 40, slow: 20, deadband: 3, expected: .up,
                 note: "the fast average leading is up"),
            Case(fast: 20, slow: 40, deadband: 3, expected: .down,
                 note: "the fast average trailing is down"),
            Case(fast: 21, slow: 20, deadband: 3, expected: .flat,
                 note: "a gap inside the deadband is flat"),
            Case(fast: 23, slow: 20, deadband: 3, expected: .up,
                 note: "a gap sitting exactly on the deadband reads as movement"),
            Case(fast: 17, slow: 20, deadband: 3, expected: .down,
                 note: "…in either direction"),
            Case(fast: 85, slow: 26, deadband: 3, expected: .up,
                 note: "a spike the slow average has barely felt still reads as rising"),
        ])
        func classifies(testCase: Case) {
            let direction = TrendDirection.between(
                fast: testCase.fast, slow: testCase.slow, deadband: testCase.deadband
            )
            #expect(direction == testCase.expected)
        }
    }
}

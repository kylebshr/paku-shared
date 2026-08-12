import Foundation
import Testing
@testable import PakuShared

/// Floors to a 30-minute boundary for deterministic timestamps.
private func alignedToHalfHour(_ date: Date) -> Date {
    let slot: TimeInterval = 30 * 60
    return Date(
        timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / slot).rounded(.down) * slot
    )
}

private func makePoint(pm2_5: Double?, timestamp: Date) -> SensorHistoryResponse.DataPoint {
    SensorHistoryResponse.DataPoint(
        timestamp: timestamp,
        pm1_0: nil,
        pm2_5: pm2_5,
        pm10_0: nil,
        humidity: nil,
        temperature: nil,
        voc: nil,
        confidence: nil
    )
}

@Suite("LiveActivityContentState")
struct LiveActivityContentStateTests {

    @Suite("Wire shape")
    struct WireShape {
        /// The compact property names are the wire contract between the app
        /// and the server — the payload must contain exactly these keys and
        /// nothing else.
        @Test("Encoding uses exactly the compact keys")
        func encodingUsesExactCompactKeys() throws {
            let state = LiveActivityContentState(
                id: 12345,
                a: 101.5,
                t: 1,
                d: 1234.5,
                ls: Date(),
                h: [.init(t: Date(), v: 102)]
            )

            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
            let object = try #require(json as? [String: Any])
            #expect(Set(object.keys) == ["id", "a", "t", "d", "ls", "h"])

            let points = try #require(object["h"] as? [[String: Any]])
            #expect(points.count == 1)
            #expect(Set(points[0].keys) == ["t", "v"])
        }

        /// nil optionals must be omitted entirely — they cost zero payload
        /// bytes.
        @Test("Encoding omits nil optionals")
        func encodingOmitsNilOptionals() throws {
            let state = LiveActivityContentState(id: 1, a: 42, t: nil, d: nil, ls: nil, h: nil)

            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
            let object = try #require(json as? [String: Any])
            #expect(Set(object.keys) == ["id", "a"])
        }

        /// Dates ride the default JSONEncoder strategy (seconds since 2001
        /// as a double) — both sides encode/decode with matching defaults.
        @Test("Dates encode as reference-date doubles")
        func datesEncodeAsReferenceDateDoubles() throws {
            let lastSeen = Date(timeIntervalSinceReferenceDate: 761_234_567.25)
            let state = LiveActivityContentState(id: 1, a: 42, t: nil, d: nil, ls: lastSeen, h: nil)

            let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
            let object = try #require(json as? [String: Any])
            #expect(object["ls"] as? Double == 761_234_567.25)
        }

        /// Worst case — a full 49-point history and every optional set —
        /// must leave plenty of headroom under the ~4KB APNs payload limit.
        @Test("The worst-case state stays under the payload budget")
        func worstCaseStateStaysUnderPayloadBudget() throws {
            let now = Date()
            let points = (0..<49).map { index in
                LiveActivityContentState.Point(
                    t: now.addingTimeInterval(TimeInterval(-30 * 60 * index)),
                    v: 500
                )
            }

            let state = LiveActivityContentState(
                id: Int(Int32.max),
                a: 500.123456789,
                t: -1,
                d: 99999.123456789,
                ls: now,
                h: points
            )

            let encoded = try JSONEncoder().encode(state)
            #expect(encoded.count < 3000, "Worst case encoded to \(encoded.count) bytes")
        }
    }

    @Suite("Builder")
    struct Builder {
        @Test("Carries the sensor's current values")
        func buildsCurrentValues() throws {
            let now = Date()
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: now.addingTimeInterval(-120))

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: 250, history: [], now: now
            )

            #expect(state.id == sensor.id)
            #expect(state.a == sensor.aqiValue(period: .now, conversion: .none))
            #expect(state.d == 250)
            #expect(state.ls == sensor.lastSeen)
        }

        /// The current point lands on lastSeen exactly, clamped to now.
        @Test("The synthetic point never exceeds now", arguments: [
            (lastSeenOffset: -4.0 * 60, isClamped: false),
            (lastSeenOffset: 10.0 * 60, isClamped: true),
        ])
        func syntheticPointNeverExceedsNow(lastSeenOffset: TimeInterval, isClamped: Bool) throws {
            let now = Date()
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: now.addingTimeInterval(lastSeenOffset))

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: [], now: now
            )

            #expect(state.h?.last?.t == (isClamped ? now : sensor.lastSeen))
        }
    }

    @Suite("Trend")
    struct Trend {
        /// A sensor's fast and slow averages, and the arrow they should
        /// produce.
        struct Case: Sendable, CustomTestStringConvertible {
            let pm2_5: Double
            let tenMinute: Double
            let sixtyMinute: Double
            let expected: Int
            let note: String

            var testDescription: String { note }
        }

        @Test("Comes off the sensor's own averages", arguments: [
            Case(pm2_5: 40, tenMinute: 40, sixtyMinute: 10, expected: 1,
                 note: "the fast average leading the slow reads as rising"),
            Case(pm2_5: 10, tenMinute: 10, sixtyMinute: 40, expected: -1,
                 note: "the fast average trailing the slow reads as falling"),
            Case(pm2_5: 20, tenMinute: 20, sixtyMinute: 20, expected: 0,
                 note: "averages that agree read as flat"),
            Case(pm2_5: 11.1, tenMinute: 11.1, sixtyMinute: 10.9, expected: 0,
                 note: "a sub-unit jiggle straddling an integer stays inside the deadband"),
        ])
        func trendFromAverages(testCase: Case) throws {
            let now = Date()
            let sensor = try Sensor.stub(
                pm2_5: testCase.pm2_5,
                pm2_5_10minute: testCase.tenMinute,
                pm2_5_60minute: testCase.sixtyMinute,
                lastSeen: now
            )

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: [], now: now
            )

            #expect(state.t == testCase.expected)
        }

        /// The trend comes off the sensor's own averages, not history — an
        /// arrow renders even when the history query comes back empty.
        @Test("History has no say in the trend")
        func trendIgnoresHistoryEntirely() throws {
            let now = Date()
            let sensor = try Sensor.stub(
                pm2_5: 20, pm2_5_10minute: 40, pm2_5_60minute: 20, lastSeen: now
            )

            // Steeply falling rows must have no say.
            let fallingRows: [SensorHistoryResponse.DataPoint] = (0..<4).map { index in
                let value: Double = 80 - Double(index) * 20
                let age: TimeInterval = -1800 * Double(4 - index)
                return makePoint(pm2_5: value, timestamp: now.addingTimeInterval(age))
            }

            let withoutHistory = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: [], now: now
            )
            let withContraryHistory = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: fallingRows, now: now
            )

            #expect(withoutHistory.t == 1)
            #expect(withContraryHistory.t == 1, "History must not sway the crossover")
        }

        /// A quiet sensor's averages are frozen; no trend.
        @Test("A stale sensor draws no arrow")
        func trendIsNilForStaleSensor() throws {
            let now = Date()
            let sensor = try Sensor.stub(
                pm2_5: 20, pm2_5_10minute: 40, pm2_5_60minute: 20,
                lastSeen: now.addingTimeInterval(-90 * 60)
            )

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: [], now: now
            )

            #expect(state.t == nil)
        }
    }

    @Suite("History")
    struct History {
        /// The last 24 hours oldest→newest, plus the current reading at
        /// lastSeen.
        @Test("Sorts ascending, drops out-of-window rows, appends the current point")
        func windowOrderingAndSyntheticCurrentPoint() throws {
            let now = Date()
            let lastSeen = now.addingTimeInterval(-90)
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: lastSeen)

            let history = [
                makePoint(pm2_5: 10, timestamp: now.addingTimeInterval(-2 * 60 * 60)),
                makePoint(pm2_5: 15, timestamp: now.addingTimeInterval(-25 * 60 * 60)), // outside window
                makePoint(pm2_5: 12, timestamp: now.addingTimeInterval(-4 * 60 * 60)),
            ]

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: history, now: now
            )

            let points = try #require(state.h)
            #expect(points.count == 3, "Two in-window rows plus the synthetic current point")
            #expect(
                points.map(\.t)
                    == [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-2 * 60 * 60), lastSeen]
            )
            #expect(points.last?.v == Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()))
        }

        /// The ≤49-point APNs budget: cap, dropping the oldest.
        @Test("Caps at 49 points, dropping the oldest")
        func cappedAtFortyNinePoints() throws {
            let now = Date()
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: now)

            // 49 rows in-window; with the current point appended, one over cap.
            var history = (0..<48).map { index in
                makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(TimeInterval(-30 - 1800 * index)))
            }
            history.append(makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-24 * 60 * 60 + 60)))

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: history, now: now
            )

            let points = try #require(state.h)
            #expect(points.count == 49)
            #expect(points.last?.t == sensor.lastSeen, "The current point must survive the cap")
            #expect(points.first?.t == now.addingTimeInterval(-30 - 1800 * 47), "The oldest row is dropped")
        }

        /// Rows newer than lastSeen carry frozen data for an offline sensor;
        /// dropping them keeps the points ascending.
        @Test("Clamps to lastSeen for an offline sensor")
        func clampsToLastSeenForOfflineSensor() throws {
            let now = Date()
            let lastSeen = now.addingTimeInterval(-2 * 60 * 60)
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: lastSeen)

            let history = [
                makePoint(pm2_5: 10, timestamp: now.addingTimeInterval(-4 * 60 * 60)),
                makePoint(pm2_5: 12, timestamp: now.addingTimeInterval(-3 * 60 * 60)),
                makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-90 * 60)), // after lastSeen
                makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-30 * 60)), // after lastSeen
            ]

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: history, now: now
            )

            let points = try #require(state.h)
            #expect(
                points.map(\.t)
                    == [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-3 * 60 * 60), lastSeen],
                "Rows newer than lastSeen are dropped; the synthetic point comes last"
            )
            #expect(points.map(\.t) == points.map(\.t).sorted(), "Points must be chronologically ascending")
        }

        /// The current point may share a timestamp with the newest row — the
        /// client re-bins; points just must never go backwards.
        @Test("The current point coexists with a row sharing its slot")
        func currentPointCoexistsWithARowSharingItsSlot() throws {
            let base = alignedToHalfHour(Date())
            let lastSeen = base.addingTimeInterval(10 * 60)
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: lastSeen)

            let history = [
                makePoint(pm2_5: 12, timestamp: base.addingTimeInterval(-30 * 60)),
                makePoint(pm2_5: 10, timestamp: base), // shares lastSeen's slot
                makePoint(pm2_5: 10, timestamp: lastSeen), // exactly lastSeen
            ]

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: history, now: lastSeen
            )

            let points = try #require(state.h)
            #expect(
                points.map(\.t) == points.map(\.t).sorted(),
                "Points must never go backwards, duplicates included"
            )
            #expect(points.last?.t == lastSeen)
            #expect(
                points.last?.v == Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()),
                "The trailing point carries the current reading"
            )
        }

        @Test("Skips points without readings")
        func skipsPointsWithoutReadings() throws {
            let now = Date()
            let sensor = try Sensor.stub(pm2_5: 20, lastSeen: now)

            // Offline gaps are stored as all-nil points; they can't chart.
            let empty = makePoint(pm2_5: nil, timestamp: now.addingTimeInterval(-60 * 60))

            let state = LiveActivityContentState.build(
                sensor: sensor, conversion: .none, distance: nil, history: [empty], now: now
            )

            #expect(state.h?.count == 1, "Only the current point")
            #expect(state.t == 0, "The trend comes off the sensor, not the reading-less row")
        }
    }
}

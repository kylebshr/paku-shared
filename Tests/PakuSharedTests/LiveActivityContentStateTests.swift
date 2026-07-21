import XCTest
@testable import PakuShared

final class LiveActivityContentStateTests: XCTestCase {

    // MARK: Wire shape

    // The compact property names are the wire contract between the app and
    // the server — the payload must contain exactly these keys and nothing
    // else.
    func testEncodingUsesExactCompactKeys() throws {
        let state = LiveActivityContentState(
            id: 12345,
            a: 101.5,
            t: 1,
            d: 1234.5,
            ls: Date(),
            h: [.init(t: Date(), v: 102)]
        )

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        let object = try XCTUnwrap(json as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "a", "t", "d", "ls", "h"])

        let points = try XCTUnwrap(object["h"] as? [[String: Any]])
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(Set(points[0].keys), ["t", "v"])
    }

    // nil optionals must be omitted entirely — they cost zero payload bytes.
    func testEncodingOmitsNilOptionals() throws {
        let state = LiveActivityContentState(id: 1, a: 42, t: nil, d: nil, ls: nil, h: nil)

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        let object = try XCTUnwrap(json as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["id", "a"])
    }

    // Dates ride the default JSONEncoder strategy (seconds since 2001 as a
    // double) — both sides encode/decode with matching defaults.
    func testDatesEncodeAsReferenceDateDoubles() throws {
        let lastSeen = Date(timeIntervalSinceReferenceDate: 761_234_567.25)
        let state = LiveActivityContentState(id: 1, a: 42, t: nil, d: nil, ls: lastSeen, h: nil)

        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        let object = try XCTUnwrap(json as? [String: Any])
        XCTAssertEqual(object["ls"] as? Double, 761_234_567.25)
    }

    // Worst case — a full 49-point history and every optional set — must
    // leave plenty of headroom under the ~4KB APNs payload limit.
    func testWorstCaseStateStaysUnderPayloadBudget() throws {
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
        print("Worst-case content-state payload: \(encoded.count) bytes")
        XCTAssertLessThan(encoded.count, 3000)
    }

    // MARK: Builder

    func testBuilderBuildsCurrentValues() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now.addingTimeInterval(-120))

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: 250,
            history: [],
            now: now
        )

        XCTAssertEqual(state.id, sensor.id)
        XCTAssertEqual(state.a, sensor.aqiValue(period: .now, conversion: .none))
        XCTAssertEqual(state.d, 250)
        XCTAssertEqual(state.ls, sensor.lastSeen)
    }

    // The current point lands on lastSeen exactly, clamped to now.
    func testSyntheticPointNeverExceedsNow() throws {
        let now = Date()

        let recent = try makeSensor(pm2_5: 20, lastSeen: now.addingTimeInterval(-4 * 60))
        let recentState = LiveActivityContentState.build(
            sensor: recent, conversion: .none, distance: nil, history: [], now: now
        )
        XCTAssertEqual(recentState.h?.last?.t, recent.lastSeen)

        // A clock-skewed sensor reporting from the future is clamped to now.
        let skewed = try makeSensor(pm2_5: 20, lastSeen: now.addingTimeInterval(10 * 60))
        let skewedState = LiveActivityContentState.build(
            sensor: skewed, conversion: .none, distance: nil, history: [], now: now
        )
        XCTAssertEqual(skewedState.h?.last?.t, now)
    }

    // The trend comes off the sensor's own averages, not history — an
    // arrow renders even when the history query comes back empty.
    func testTrendIgnoresHistoryEntirely() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, pm2_5_10minute: 40, pm2_5_60minute: 20, lastSeen: now)

        let withoutHistory = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )
        // Steeply falling rows must have no say.
        let fallingRows: [SensorHistoryResponse.DataPoint] = (0..<4).map { index in
            let value: Double = 80 - Double(index) * 20
            let age: TimeInterval = -1800 * Double(4 - index)
            return makePoint(pm2_5: value, timestamp: now.addingTimeInterval(age))
        }

        let withContraryHistory = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: fallingRows, now: now
        )

        XCTAssertEqual(withoutHistory.t, 1)
        XCTAssertEqual(withContraryHistory.t, 1, "History must not sway the crossover")
    }

    // A quiet sensor's averages are frozen; no trend.
    func testTrendIsNilForStaleSensor() throws {
        let now = Date()
        let sensor = try makeSensor(
            pm2_5: 20, pm2_5_10minute: 40, pm2_5_60minute: 20,
            lastSeen: now.addingTimeInterval(-90 * 60)
        )

        let state = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )

        XCTAssertNil(state.t)
    }

    // A sub-unit jiggle straddling an integer stays inside the deadband.
    func testTrendFlatForIntegerBoundaryJitter() throws {
        let now = Date()
        // ~1:1 with AQI down here, so the gap stays inside the deadband.
        let sensor = try makeSensor(
            pm2_5: 11.1, pm2_5_10minute: 11.1, pm2_5_60minute: 10.9, lastSeen: now
        )

        let state = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )

        XCTAssertEqual(state.t, 0)
    }

    func testTrendUpWhenFastAverageLeadsSlow() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 40, pm2_5_10minute: 40, pm2_5_60minute: 10, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )

        XCTAssertEqual(state.t, 1)
    }

    func testTrendDownWhenFastAverageTrailsSlow() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 10, pm2_5_10minute: 10, pm2_5_60minute: 40, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )

        XCTAssertEqual(state.t, -1)
    }

    func testTrendFlatWhenAveragesAgree() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )

        XCTAssertEqual(state.t, 0)
    }


    // The last 24 hours oldest→newest, plus the current reading at lastSeen.
    func testHistoryWindowOrderingAndSyntheticCurrentPoint() throws {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-90)
        let sensor = try makeSensor(pm2_5: 20, lastSeen: lastSeen)

        let history = [
            makePoint(pm2_5: 10, timestamp: now.addingTimeInterval(-2 * 60 * 60)),
            makePoint(pm2_5: 15, timestamp: now.addingTimeInterval(-25 * 60 * 60)), // outside window
            makePoint(pm2_5: 12, timestamp: now.addingTimeInterval(-4 * 60 * 60)),
        ]

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: now
        )

        let points = try XCTUnwrap(state.h)
        XCTAssertEqual(points.count, 3, "Two in-window rows plus the synthetic current point")
        XCTAssertEqual(
            points.map(\.t),
            [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-2 * 60 * 60), lastSeen]
        )
        XCTAssertEqual(points.last?.v, Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()))
    }

    // Rows chart their recorded peak, falling back to the sampled value.
    func testHistoryPrefersRowPeakOverSampledValue() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        let history = [
            makePoint(pm2_5: 10, pm2_5_max: 30, timestamp: now.addingTimeInterval(-60 * 60)),
            makePoint(pm2_5: 12, timestamp: now.addingTimeInterval(-30 * 60)),
        ]

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: now
        )

        let points = try XCTUnwrap(state.h)
        let peak = AQI.value(for: 30, humidity: nil, conversion: .none, location: .outdoors)
        let sample = AQI.value(for: 12, humidity: nil, conversion: .none, location: .outdoors)
        XCTAssertEqual(points[0].v, Int16(peak.rounded()), "A row with a recorded peak charts the peak")
        XCTAssertEqual(points[1].v, Int16(sample.rounded()), "A row without one falls back to the sample")
    }

    // The ≤49-point APNs budget: cap, dropping the oldest.
    func testHistoryIsCappedAtFortyNinePointsDroppingOldest() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        // 49 rows in-window; with the current point appended, one over cap.
        var history = (0..<48).map { index in
            makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(TimeInterval(-30 - 1800 * index)))
        }
        history.append(makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-24 * 60 * 60 + 60)))

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: now
        )

        let points = try XCTUnwrap(state.h)
        XCTAssertEqual(points.count, 49)
        XCTAssertEqual(points.last?.t, sensor.lastSeen, "The current point must survive the cap")
        XCTAssertEqual(points.first?.t, now.addingTimeInterval(-30 - 1800 * 47), "The oldest row is dropped")
    }

    // Rows newer than lastSeen carry frozen data for an offline sensor;
    // dropping them keeps the points ascending.
    func testHistoryClampsToLastSeenForOfflineSensor() throws {
        let now = Date()
        let lastSeen = now.addingTimeInterval(-2 * 60 * 60)
        let sensor = try makeSensor(pm2_5: 20, lastSeen: lastSeen)

        let history = [
            makePoint(pm2_5: 10, timestamp: now.addingTimeInterval(-4 * 60 * 60)),
            makePoint(pm2_5: 12, timestamp: now.addingTimeInterval(-3 * 60 * 60)),
            makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-90 * 60)), // after lastSeen
            makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-30 * 60)), // after lastSeen
        ]

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: now
        )

        let points = try XCTUnwrap(state.h)
        XCTAssertEqual(
            points.map(\.t),
            [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-3 * 60 * 60), lastSeen],
            "Rows newer than lastSeen are dropped; the synthetic point comes last"
        )
        XCTAssertEqual(
            points.map(\.t),
            points.map(\.t).sorted(),
            "Points must be chronologically ascending"
        )
    }

    // The current point may share a timestamp with the newest row — the
    // client re-bins; points just must never go backwards.
    func testCurrentPointCoexistsWithARowSharingItsSlot() throws {
        let base = alignedToHalfHour(Date())
        let lastSeen = base.addingTimeInterval(10 * 60)
        let sensor = try makeSensor(pm2_5: 20, lastSeen: lastSeen)

        let history = [
            makePoint(pm2_5: 12, timestamp: base.addingTimeInterval(-30 * 60)),
            makePoint(pm2_5: 10, timestamp: base), // shares lastSeen's slot
            makePoint(pm2_5: 10, timestamp: lastSeen), // exactly lastSeen
        ]

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: lastSeen
        )

        let points = try XCTUnwrap(state.h)
        XCTAssertEqual(
            points.map(\.t),
            points.map(\.t).sorted(),
            "Points must never go backwards, duplicates included"
        )
        XCTAssertEqual(points.last?.t, lastSeen)
        XCTAssertEqual(
            points.last?.v,
            Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()),
            "The trailing point carries the current reading"
        )
    }

    func testHistorySkipsPointsWithoutReadings() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        // Offline gaps are stored as all-nil points; they can't chart.
        let empty = makePoint(pm2_5: nil, timestamp: now.addingTimeInterval(-60 * 60))

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: [empty],
            now: now
        )

        XCTAssertEqual(state.h?.count, 1, "Only the current point")
        XCTAssertEqual(state.t, 0, "The trend comes off the sensor, not the reading-less row")
    }

    // MARK: Helpers

    /// Floors to a 30-minute boundary for deterministic timestamps.
    private func alignedToHalfHour(_ date: Date) -> Date {
        let slot: TimeInterval = 30 * 60
        return Date(
            timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / slot).rounded(.down) * slot
        )
    }

    /// The averages default to `pm2_5` (a flat crossover); set them apart
    /// to drive a trend.
    private func makeSensor(
        pm2_5: Double,
        pm2_5_10minute: Double? = nil,
        pm2_5_60minute: Double? = nil,
        lastSeen: Date
    ) throws -> Sensor {
        let tenMinutes = pm2_5_10minute ?? pm2_5
        let sixtyMinutes = pm2_5_60minute ?? pm2_5
        return try makeSensor(
            pm2_5: pm2_5, tenMinutes: tenMinutes, sixtyMinutes: sixtyMinutes, lastSeen: lastSeen
        )
    }

    private func makeSensor(
        pm2_5: Double,
        tenMinutes: Double,
        sixtyMinutes: Double,
        lastSeen: Date
    ) throws -> Sensor {
        try Sensor(response: SensorResponse(
            id: 12345,
            name: "Test Sensor",
            latitude: 0,
            longitude: 0,
            locationType: .outdoors,
            lastSeen: lastSeen,
            altitude: nil,
            humidity: nil,
            confidence: nil,
            temperature: nil,
            pm2_5: pm2_5,
            pm2_5_cf_1: pm2_5,
            pm2_5_10minute: tenMinutes,
            pm2_5_30minute: pm2_5,
            pm2_5_60minute: sixtyMinutes,
            pm2_5_6hour: pm2_5,
            pm2_5_24hour: pm2_5,
            pm2_5_1week: pm2_5,
            pm1_0: nil,
            pm10_0: nil,
            voc: nil
        ))
    }

    private func makePoint(pm2_5: Double?, pm2_5_max: Double? = nil, timestamp: Date) -> SensorHistoryResponse.DataPoint {
        SensorHistoryResponse.DataPoint(
            timestamp: timestamp,
            pm1_0: nil,
            pm2_5: pm2_5,
            pm2_5_max: pm2_5_max,
            pm10_0: nil,
            humidity: nil,
            temperature: nil,
            voc: nil,
            confidence: nil
        )
    }
}

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

    // The current point is stamped at lastSeen and must never sit in the
    // future — the old builder snapped it to the *nearest* half hour, which
    // rounded up to 15 minutes ahead of the clock.
    func testSyntheticPointNeverExceedsNow() throws {
        let now = Date()

        // lastSeen a few minutes back: the point lands on it exactly, with
        // no rounding up to the next half-hour slot.
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

    // The trend no longer reads history at all: it crosses the sensor's own
    // 10-minute average against its 60-minute one, so an arrow renders even
    // when the history query comes back empty.
    func testTrendIgnoresHistoryEntirely() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, pm2_5_10minute: 40, pm2_5_60minute: 20, lastSeen: now)

        let withoutHistory = LiveActivityContentState.build(
            sensor: sensor, conversion: .none, distance: nil, history: [], now: now
        )
        // Steeply falling rows — under the old slope rule this drove the
        // arrow down; now it has no say.
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

    // A sensor quiet for over an hour has frozen averages, so a crossover
    // between them describes nothing current.
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

    // The old rule compared Int-truncated values, so a sub-unit difference
    // straddling an integer rendered an arrow. The deadband is a real level
    // difference now — 3 AQI.
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


    // History is the last 24 hours oldest→newest plus the current reading
    // stamped at the sensor's raw lastSeen.
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
        XCTAssertEqual(points.count, 3, "Two in-window buckets plus the synthetic current point")
        XCTAssertEqual(
            points.map(\.t),
            [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-2 * 60 * 60), lastSeen]
        )
        XCTAssertEqual(points.last?.v, Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()))
    }

    // Input denser than the server's cadence is thinned to one point per 30
    // minutes, stamped with the newest timestamp in the slot and carrying
    // the slot's *worst* reading — averaging would dilute a spike before the
    // chart ever saw it.
    func testHistoryThinsDenseInputKeepingWorstReading() throws {
        // A slot-aligned base makes the thinning boundaries deterministic.
        let base = alignedToHalfHour(Date())
        let now = base
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        let history = [
            makePoint(pm2_5: 10, timestamp: base.addingTimeInterval(-65 * 60)), // slot A
            makePoint(pm2_5: 30, timestamp: base.addingTimeInterval(-61 * 60)), // slot A
            makePoint(pm2_5: 20, timestamp: base.addingTimeInterval(-45 * 60)), // slot B
        ]

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: history,
            now: now
        )

        let points = try XCTUnwrap(state.h)
        XCTAssertEqual(points.count, 3, "Two thinned slots plus the current point")
        XCTAssertEqual(
            points[0].t,
            base.addingTimeInterval(-61 * 60),
            "A thinned slot is stamped with its newest timestamp"
        )

        let slotAWorst = AQI.value(for: 30, humidity: nil, conversion: .none, location: .outdoors)
        XCTAssertEqual(points[0].v, Int16(slotAWorst.rounded()), "A thinned slot carries its worst reading")
    }

    // A 24-hour window can straddle at most 49 half-hour slots; with the
    // current point appended on top the builder must cap at 49, dropping
    // the oldest — the ≤49-point APNs budget is why the thinning exists.
    func testHistoryIsCappedAtFortyNinePointsDroppingOldest() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        // 48 slots marching back from just before lastSeen, plus one in
        // the partial slot at the window's old edge: 49 slots in-window.
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
        XCTAssertEqual(points.first?.t, now.addingTimeInterval(-30 - 1800 * 47), "The oldest bucket is dropped")
    }

    // The server stamps a history row for every cached sensor even after it
    // stops reporting, so an offline sensor accrues buckets newer than its
    // lastSeen carrying frozen data. Those must be dropped so the points
    // (with the synthetic current point appended) stay chronologically
    // ascending.
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
            "Buckets newer than lastSeen are dropped; the synthetic point comes last"
        )
        XCTAssertEqual(
            points.map(\.t),
            points.map(\.t).sorted(),
            "Points must be chronologically ascending"
        )
    }

    // The current point is appended at its raw timestamp with no collision
    // pass, so it can share a slot — even an exact timestamp — with the
    // newest thinned point. That's fine: the client re-bins, and the only
    // hard requirement is that points never go backwards.
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

    /// Floors to a 30-minute boundary so thinning-slot boundaries in a test
    /// don't depend on what time it happens to run.
    private func alignedToHalfHour(_ date: Date) -> Date {
        let slot: TimeInterval = 30 * 60
        return Date(
            timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / slot).rounded(.down) * slot
        )
    }

    /// The 10- and 60-minute averages default to `pm2_5`, which makes the
    /// crossover flat — set them apart to drive a trend.
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
}

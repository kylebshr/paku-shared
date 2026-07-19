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

    func testTrendIsNilWithoutRecentHistory() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        // A point outside the one-hour lookback contributes to the chart but
        // not the trend.
        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: [makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-2 * 60 * 60))],
            now: now
        )

        XCTAssertNil(state.t)
    }

    func testTrendUpWhenCurrentAboveRecentAverage() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 30, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: [makePoint(pm2_5: 10, timestamp: now.addingTimeInterval(-30 * 60))],
            now: now
        )

        XCTAssertEqual(state.t, 1)
    }

    func testTrendDownWhenCurrentBelowRecentAverage() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 10, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: [makePoint(pm2_5: 30, timestamp: now.addingTimeInterval(-30 * 60))],
            now: now
        )

        XCTAssertEqual(state.t, -1)
    }

    func testTrendFlatWhenCurrentMatchesRecentAverage() throws {
        let now = Date()
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        let state = LiveActivityContentState.build(
            sensor: sensor,
            conversion: .none,
            distance: nil,
            history: [makePoint(pm2_5: 20, timestamp: now.addingTimeInterval(-30 * 60))],
            now: now
        )

        XCTAssertEqual(state.t, 0)
    }

    // History is the last 24 hours oldest→newest plus a synthetic current
    // point stamped with the sensor's lastSeen rounded to the half-hour grid.
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
            [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-2 * 60 * 60), lastSeen.nearestHalfHour()]
        )
        XCTAssertEqual(points.last?.v, Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()))
    }

    // Points sharing a half-hour grid slot merge into one bucket carrying
    // the average reading, stamped with the newest timestamp in the slot —
    // the builder must be robust to input denser than the server's cadence.
    func testHistoryBinsDenseInputIntoHalfHourBuckets() throws {
        // A grid-aligned base makes the bucket boundaries deterministic.
        let base = Date().nearestHalfHour()
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
        XCTAssertEqual(points.count, 3, "Two merged buckets plus the synthetic current point")
        XCTAssertEqual(
            points[0].t,
            base.addingTimeInterval(-61 * 60),
            "A merged bucket is stamped with its newest timestamp"
        )

        let slotAAverage = [
            AQI.value(for: 10, humidity: nil, conversion: .none, location: .outdoors),
            AQI.value(for: 30, humidity: nil, conversion: .none, location: .outdoors),
        ].average()
        XCTAssertEqual(points[0].v, Int16(slotAAverage.rounded()), "A merged bucket carries the average reading")
    }

    // A 24-hour window can straddle at most 49 half-hour grid slots; with
    // the synthetic point appended on top the builder must cap at 49,
    // dropping the oldest.
    func testHistoryIsCappedAtFortyNinePointsDroppingOldest() throws {
        // lastSeen sits mid-slot so the window straddles 49 distinct slots
        // and the synthetic point rounds up past every bucket.
        let base = Date().nearestHalfHour()
        let now = base.addingTimeInterval(15 * 60)
        let sensor = try makeSensor(pm2_5: 20, lastSeen: now)

        // 48 buckets marching back from just before lastSeen, plus one in
        // the partial slot at the window's old edge: 49 buckets in-window.
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
        XCTAssertEqual(points.last?.t, sensor.lastSeen.nearestHalfHour(), "The synthetic point must survive the cap")
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
            [now.addingTimeInterval(-4 * 60 * 60), now.addingTimeInterval(-3 * 60 * 60), lastSeen.nearestHalfHour()],
            "Buckets newer than lastSeen are dropped; the synthetic point comes last"
        )
        XCTAssertEqual(
            points.map(\.t),
            points.map(\.t).sorted(),
            "Points must be chronologically ascending"
        )
    }

    // The synthetic point lands on the half-hour grid; a bucket already
    // stamped in that slot is superseded by the current reading, so the
    // chart never renders two overlapping trailing bars.
    func testSyntheticPointAlignsToGridAndReplacesCollidingBucket() throws {
        // A grid-aligned base makes the rounding deterministic.
        let base = Date().nearestHalfHour()
        let lastSeen = base.addingTimeInterval(10 * 60) // rounds back down to base
        let now = lastSeen
        let sensor = try makeSensor(pm2_5: 20, lastSeen: lastSeen)

        let history = [
            makePoint(pm2_5: 12, timestamp: base.addingTimeInterval(-30 * 60)),
            makePoint(pm2_5: 10, timestamp: base), // shares lastSeen's grid slot
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
            [base.addingTimeInterval(-30 * 60), base],
            "Exactly one trailing point, on the grid — the colliding bucket is replaced"
        )
        XCTAssertEqual(
            points.last?.v,
            Int16(sensor.aqiValue(period: .now, conversion: .none).rounded()),
            "The trailing point carries the current reading, not the superseded bucket"
        )
        for (older, newer) in zip(points, points.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                newer.t.timeIntervalSince(older.t),
                30 * 60,
                "Points must sit at least one bucket apart"
            )
        }
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

        XCTAssertEqual(state.h?.count, 1, "Only the synthetic current point")
        XCTAssertNil(state.t, "A reading-less point can't contribute to the trend")
    }

    // MARK: Helpers

    private func makeSensor(pm2_5: Double, lastSeen: Date) throws -> Sensor {
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
            pm2_5_10minute: pm2_5,
            pm2_5_30minute: pm2_5,
            pm2_5_60minute: pm2_5,
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

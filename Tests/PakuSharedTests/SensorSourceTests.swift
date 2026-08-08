import XCTest
@testable import PakuShared

final class SensorSourceTests: XCTestCase {
    func test_purpleAirRangeStaysPurpleAir() {
        XCTAssertEqual(SensorIDSpace.source(of: 1), .purpleAir)
        XCTAssertEqual(SensorIDSpace.source(of: 214_591), .purpleAir)
        XCTAssertEqual(SensorIDSpace.source(of: SensorIDSpace.airGradientOffset - 1), .purpleAir)
    }

    func test_airGradientRangeMapsToAirGradient() {
        XCTAssertEqual(SensorIDSpace.source(of: SensorIDSpace.airGradientOffset), .airGradient)
        XCTAssertEqual(SensorIDSpace.source(of: SensorIDSpace.airGradientSensorID(locationID: 89)), .airGradient)
    }

    func test_airGradientIDsRoundTrip() {
        let sensorID = SensorIDSpace.airGradientSensorID(locationID: 9_999_999)
        XCTAssertEqual(sensorID, 2_009_999_999)
        XCTAssertEqual(SensorIDSpace.airGradientLocationID(from: sensorID), 9_999_999)
        XCTAssertNil(SensorIDSpace.airGradientLocationID(from: 214_591))
    }

    func test_sensorResponseDerivesSourceFromID() throws {
        let purpleAir = SensorResponse(
            id: 214_591,
            name: "PurpleAir",
            latitude: 45.5,
            longitude: -122.6,
            locationType: .outdoors,
            lastSeen: Date()
        )
        XCTAssertEqual(purpleAir.source, .purpleAir)

        let airGradient = SensorResponse(
            id: SensorIDSpace.airGradientSensorID(locationID: 89),
            name: "AirGradient",
            latitude: 18.9,
            longitude: 98.9,
            locationType: .outdoors,
            lastSeen: Date(),
            pm2_5: 8,
            pm2_5_cf_1: 8,
            pm2_5_10minute: 8,
            pm2_5_30minute: 8,
            pm2_5_60minute: 8
        )
        XCTAssertEqual(airGradient.source, .airGradient)
        XCTAssertEqual(try Sensor(response: airGradient).source, .airGradient)
    }
}

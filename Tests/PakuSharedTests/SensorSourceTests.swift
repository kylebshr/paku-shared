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

    func test_epaConversionOnlyAppliesToPurpleAirSensors() throws {
        func sensor(id: Int) throws -> Sensor {
            try Sensor(response: SensorResponse(
                id: id,
                name: "Sensor",
                latitude: 45.5,
                longitude: -122.6,
                locationType: .outdoors,
                lastSeen: Date(),
                humidity: 50,
                pm2_5: 20,
                pm2_5_cf_1: 20,
                pm2_5_10minute: 20,
                pm2_5_30minute: 20,
                pm2_5_60minute: 20
            ))
        }

        let purpleAir = try sensor(id: 214_591)
        XCTAssertNotEqual(
            purpleAir.aqiValue(period: .now, conversion: .EPA),
            purpleAir.aqiValue(period: .now, conversion: .none)
        )

        let airGradient = try sensor(id: SensorIDSpace.airGradientSensorID(locationID: 89))
        XCTAssertEqual(
            airGradient.aqiValue(period: .now, conversion: .EPA),
            airGradient.aqiValue(period: .now, conversion: .none)
        )
        XCTAssertEqual(
            airGradient.aqiValue(period: .now, conversion: .EPA),
            purpleAir.aqiValue(period: .now, conversion: .none)
        )
    }

    func test_directoryFileAndDisplayNamePerSource() {
        XCTAssertEqual(SensorSource.purpleAir.directoryFile, "sensors.json")
        XCTAssertEqual(SensorSource.airGradient.directoryFile, "airgradient-sensors.json")
        XCTAssertEqual(SensorSource.airGradient.displayName, "AirGradient")
    }

    func test_sensorDirectoryWireShape() throws {
        let directory = SensorDirectory(asOf: 1_700_000_000, sensors: [
            .init(id: 2_000_000_089, name: "Sand Ridge", loc: .outdoors, lat: 41.3644, lon: -83.6612),
        ])

        let data = try JSONEncoder().encode(directory)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["asOf"] as? Int, 1_700_000_000)

        let entry = try XCTUnwrap((object["sensors"] as? [[String: Any]])?.first)
        XCTAssertEqual(Set(entry.keys), ["id", "name", "loc", "lat", "lon"])
        XCTAssertEqual(entry["loc"] as? Int, 0)

        XCTAssertEqual(try JSONDecoder().decode(SensorDirectory.self, from: data), directory)
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

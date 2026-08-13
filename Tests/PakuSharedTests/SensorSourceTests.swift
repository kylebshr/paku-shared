import Foundation
import Testing
@testable import PakuShared

struct SensorSourceTests {
    @Test(arguments: [1, 214_591, SensorIDSpace.airGradientOffset - 1])
    func purpleAirRangeStaysPurpleAir(id: Int) {
        #expect(SensorIDSpace.source(of: id) == .purpleAir)
    }

    @Test(arguments: [SensorIDSpace.airGradientOffset, SensorIDSpace.airGradientSensorID(locationID: 89)])
    func airGradientRangeMapsToAirGradient(id: Int) {
        #expect(SensorIDSpace.source(of: id) == .airGradient)
    }

    @Test func airGradientIDsRoundTrip() {
        let sensorID = SensorIDSpace.airGradientSensorID(locationID: 9_999_999)
        #expect(sensorID == 2_009_999_999)
        #expect(SensorIDSpace.airGradientLocationID(from: sensorID) == 9_999_999)
        #expect(SensorIDSpace.airGradientLocationID(from: 214_591) == nil)
    }

    @Test func epaConversionAppliesToPlantowerBasedSources() throws {
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
        #expect(purpleAir.aqiValue(period: .now, conversion: .EPA) != purpleAir.aqiValue(period: .now, conversion: .none))

        let airGradient = try sensor(id: SensorIDSpace.airGradientSensorID(locationID: 89))
        #expect(airGradient.aqiValue(period: .now, conversion: .EPA) != airGradient.aqiValue(period: .now, conversion: .none))
        #expect(airGradient.aqiValue(period: .now, conversion: .EPA) == purpleAir.aqiValue(period: .now, conversion: .EPA))
    }

    @Test func directoryFileAndDisplayNamePerSource() {
        #expect(SensorSource.purpleAir.directoryFile == "sensors.json")
        #expect(SensorSource.airGradient.directoryFile == "airgradient-sensors.json")
        #expect(SensorSource.airGradient.displayName == "AirGradient")
    }

    @Test func sensorDirectoryWireShape() throws {
        let directory = SensorDirectory(asOf: 1_700_000_000, sensors: [
            .init(id: 2_000_000_089, name: "Sand Ridge", loc: .outdoors, lat: 41.3644, lon: -83.6612),
        ])

        let data = try JSONEncoder().encode(directory)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["asOf"] as? Int == 1_700_000_000)

        let entry = try #require((object["sensors"] as? [[String: Any]])?.first)
        #expect(Set(entry.keys) == ["id", "name", "loc", "lat", "lon"])
        #expect(entry["loc"] as? Int == 0)

        #expect(try JSONDecoder().decode(SensorDirectory.self, from: data) == directory)
    }

    @Test func sensorResponseDerivesSourceFromID() throws {
        let purpleAir = SensorResponse(
            id: 214_591,
            name: "PurpleAir",
            latitude: 45.5,
            longitude: -122.6,
            locationType: .outdoors,
            lastSeen: Date()
        )
        #expect(purpleAir.source == .purpleAir)

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
        #expect(airGradient.source == .airGradient)
        #expect(try Sensor(response: airGradient).source == .airGradient)
    }
}

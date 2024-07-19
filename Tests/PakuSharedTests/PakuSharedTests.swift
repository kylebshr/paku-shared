import XCTest
@testable import PakuShared

final class AQITests: XCTestCase {
    func test_aqhi() throws {
        XCTAssertEqual(8, AQI.aqhi(for: 168, humidity: 40, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(2, AQI.aqhi(for: 45, humidity: 54, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(2, AQI.aqhi(for: 39, humidity: 37, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(1, AQI.aqhi(for: 0, humidity: 37, conversion: .none, location: .outdoors).rounded())
    }

    func test_aqi_outdoors() {
        XCTAssertEqual(243, AQI.value(for: 168, humidity: 40, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(124, AQI.value(for: 45, humidity: 54, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(110, AQI.value(for: 39, humidity: 37, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(0, AQI.value(for: 0, humidity: 37, conversion: .none, location: .outdoors).rounded())
    }

    func test_aqi_indoors() {
        XCTAssertEqual(243, AQI.value(for: 168, humidity: 40, conversion: .none, location: .indoors).rounded())
        XCTAssertEqual(124, AQI.value(for: 45, humidity: 54, conversion: .none, location: .indoors).rounded())
        XCTAssertEqual(110, AQI.value(for: 39, humidity: 37, conversion: .none, location: .indoors).rounded())
        XCTAssertEqual(0, AQI.value(for: 0, humidity: 37, conversion: .none, location: .indoors).rounded())
    }

    func test_epa_aqi_outdoors() {
        XCTAssertEqual(210, AQI.value(for: 168, humidity: 40, conversion: .EPA, location: .outdoors).rounded())
        XCTAssertEqual(96, AQI.value(for: 45, humidity: 54, conversion: .EPA, location: .outdoors).rounded())
        XCTAssertEqual(85, AQI.value(for: 39, humidity: 37, conversion: .EPA, location: .outdoors).rounded())
        XCTAssertEqual(14, AQI.value(for: 0, humidity: 37, conversion: .EPA, location: .outdoors).rounded())
    }

    func test_epa_aqi_indoors() {
        XCTAssertEqual(175, AQI.value(for: 168, humidity: 40, conversion: .EPA, location: .indoors).rounded())
        XCTAssertEqual(80, AQI.value(for: 45, humidity: 54, conversion: .EPA, location: .indoors).rounded())
        XCTAssertEqual(77, AQI.value(for: 39, humidity: 37, conversion: .EPA, location: .indoors).rounded())
        XCTAssertEqual(14, AQI.value(for: 0, humidity: 37, conversion: .EPA, location: .indoors).rounded())
    }
}

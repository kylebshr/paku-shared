import XCTest
@testable import PakuShared

final class AQITests: XCTestCase {
    func test_aqhi() throws {
        XCTAssertEqual(8, AQI.aqhi(for: 168, humidity: 40, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(2, AQI.aqhi(for: 45, humidity: 54, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(2, AQI.aqhi(for: 39, humidity: 37, conversion: .none, location: .outdoors).rounded())
        XCTAssertEqual(1, AQI.aqhi(for: 0, humidity: 37, conversion: .none, location: .outdoors).rounded())
    }
}

import XCTest
@testable import PakuShared

final class AQITests: XCTestCase {
    func test_aqhi() throws {
        XCTAssertEqual(9, AQI.aqhi(for: 168, humidity: 40, conversion: .none, location: .outdoors))
        XCTAssertEqual(3, AQI.aqhi(for: 45, humidity: 54, conversion: .none, location: .outdoors))
        XCTAssertEqual(2, AQI.aqhi(for: 39, humidity: 37, conversion: .none, location: .outdoors))
        XCTAssertEqual(1, AQI.aqhi(for: 0, humidity: 37, conversion: .none, location: .outdoors))
    }
}

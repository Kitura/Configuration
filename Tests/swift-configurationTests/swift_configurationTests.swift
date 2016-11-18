import XCTest
@testable import swift_configuration

class swift_configurationTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(swift_configuration().text, "Hello, World!")
    }


    static var allTests : [(String, (swift_configurationTests) -> () throws -> Void)] {
        return [
            ("testExample", testExample),
        ]
    }
}

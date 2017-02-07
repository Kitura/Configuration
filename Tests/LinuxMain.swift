import XCTest
@testable import ConfigurationTests

XCTMain([
    testCase(ConfigurationNodeTest.allTests),
    testCase(ConfigurationManagerTest.allTests),
])

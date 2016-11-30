import XCTest
@testable import SwiftConfigurationTests

XCTMain([
    testCase(ConfigurationNodeTest.allTests),
    testCase(ConfigurationManagerTest.allTests),
])

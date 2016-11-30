//
//  ConfigurationManagerTest.swift
//  SwiftConfiguration
//
//  Created by Youming Lin on 11/30/16.
//
//

import XCTest
@testable import SwiftConfiguration

class ConfigurationManagerTest: XCTestCase {
    static var allTests : [(String, (ConfigurationManagerTest) -> () throws -> Void)] {
        return [
            ("testLoadDictionary", testLoadDictionary),
        ]
    }

    func testLoadDictionary() {
        let manager = ConfigurationManager()

        manager.loadDictionary(["sub1": "sub1"])
        XCTAssertEqual(manager.getValue(for: "sub1") as? String, "sub1")
    }
}

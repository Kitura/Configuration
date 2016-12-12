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
            ("testLoadFile", testLoadFile),
        ]
    }

    func testLoadDictionary() {
        let manager = ConfigurationManager()

        manager.loadDictionary(["Hello": "World"])
        XCTAssertEqual(manager.getValue(for: "Hello") as? String, "World")
    }

    func testLoadFile() {
        let fileURL = URL(fileURLWithPath: #file).appendingPathComponent("../../../TestResources/default.json").standardized
        let manager = ConfigurationManager()

        do {
            try manager.loadFile(fileURL.path)
            XCTAssertEqual(manager.getValue(for: "OAuth.configuration.state") as? Bool, true)
        }
        catch {
            XCTFail("Cannot read file")
        }
    }
}

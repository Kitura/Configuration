//
//  ConfigurationNodeTest.swift
//  SwiftConfiguration
//
//  Created by Youming Lin on 11/29/16.
//
//

import XCTest
@testable import SwiftConfiguration

class ConfigurationNodeTest: XCTestCase {
    static var allTests : [(String, (ConfigurationNodeTest) -> () throws -> Void)] {
        return [
            ("testRawValue", testRawValue),
        ]
    }

    func testRawValue() {
        let root = ConfigurationNode()

        root.rawValue = nil
        XCTAssertNil(root.rawValue)

        root.rawValue = [:]
        XCTAssertNil(root.rawValue)

        root.rawValue = "Hello world"
        XCTAssertEqual(root.rawValue as? String, "Hello world")

        root.rawValue = ["hello": "world"]
        XCTAssertEqual(root["hello"]?.rawValue as? String, "world")
    }

    func testSubscript() {
        let root = ConfigurationNode()

        root["sub1.sub2.sub3"] = ConfigurationNode(rawValue: "Hello world")
        XCTAssertEqual(root["sub1.sub2.sub3"]?.rawValue as? String, "Hello world")
    }

    func testMergeOverwrite() {
        let root = ConfigurationNode()
        let other = ConfigurationNode()

        other.rawValue = "Hello world"
        root.merge(overwrite: other)
        XCTAssertEqual(root.rawValue as? String, "Hello world")

        root.rawValue = ["sub1": "sub1"]
        other.rawValue = [
            "sub1": "Hello world",
            "sub2": "sub2"
        ]
        root.merge(overwrite: other)
        XCTAssertEqual(root["sub1"]?.rawValue as? String, "sub1")
        XCTAssertEqual(root["sub2"]?.rawValue as? String, "sub2")
    }
}

/*
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import XCTest
@testable import SwiftConfiguration

class ConfigurationNodeTest: XCTestCase {
    static var allTests : [(String, (ConfigurationNodeTest) -> () throws -> Void)] {
        return [
            ("testRawValue", testRawValue),
            ("testSubscript", testSubscript),
            ("testMergeOverwrite", testMergeOverwrite),
        ]
    }

    func testRawValue() {
        var root = ConfigurationNode.null

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
        var root = ConfigurationNode.null

        root["sub1.sub2.sub3"] = ConfigurationNode(rawValue: "Hello world")
        XCTAssertEqual(root["sub1.sub2.sub3"]?.rawValue as? String, "Hello world")
    }

    func testMergeOverwrite() {
        var root = ConfigurationNode.null
        var other = ConfigurationNode.null

        other.rawValue = "Hello world"
        root.merge(overwrittenBy: other)
        XCTAssertEqual(root.rawValue as? String, "Hello world")

        root.rawValue = ["sub1": "sub1"]
        other.rawValue = [
            "sub1": "Hello world",
            "sub2": "sub2"
        ]
        root.merge(overwrittenBy: other)
        XCTAssertEqual(root["sub1"]?.rawValue as? String, "Hello world")
        XCTAssertEqual(root["sub2"]?.rawValue as? String, "sub2")
    }
}

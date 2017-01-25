/*
 * Copyright IBM Corporation 2017
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
            ("testSplitKeys", testSplitKeys)
        ]
    }

    func testRawValue() {
        var root = ConfigurationNode.dictionary([:])

        root.rawValue = "Hello world"
        XCTAssertEqual(root.rawValue as? String, "Hello world")

        root.rawValue = [0, "1", "hello world"]
        XCTAssertEqual(root["2"]?.rawValue as? String, "hello world")

        root.rawValue = ["hello": "world"]
        XCTAssertEqual(root["hello"]?.rawValue as? String, "world")

        root.rawValue = [
            "env": "<default>",
            "OAuth": [
                "name": "facebook",
                "configuration": [
                    "state": true,
                    "profileFields": ["displayName", "emails", "id", "name"],
                    "clientID": "<default>",
                    "clientSecret": "<default>",
                    "profileURL": "https://graph.facebook.com/v2.6/me",
                    "scope": ["email"]
                ]
            ],
            "port": "<default>"
        ]
        XCTAssertEqual(root["OAuth:configuration:state"]?.rawValue as? Bool, true)
    }

    func testSubscript() {
        var root = ConfigurationNode.dictionary([:])
        root["sub1:sub2"] = ConfigurationNode(["hello", "world"])
        XCTAssertEqual(root["sub1:sub2:1"]?.rawValue as? String, "world")

        root = ConfigurationNode.dictionary([:])
        root["sub1:sub2"] = ConfigurationNode(["sub3": "Hello world"])
        XCTAssertEqual(root["sub1:sub2:sub3"]?.rawValue as? String, "Hello world")
    }

    func testMergeOverwrite() {
        var root = ConfigurationNode.dictionary([:])
        var other = ConfigurationNode.dictionary([:])

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

    func testSplitKeys() {
        let simpleKeys = "hello".splitKeys
        XCTAssertEqual(simpleKeys.0, "hello")
        XCTAssertNil(simpleKeys.1)

        let complexKeys = "hello:world".splitKeys
        XCTAssertEqual(complexKeys.0, "hello")
        XCTAssertEqual(complexKeys.1, "world")
    }
}

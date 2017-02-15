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
@testable import Configuration

class ConfigurationManagerTest: XCTestCase {
    static var allTests : [(String, (ConfigurationManagerTest) -> () throws -> Void)] {
        return [
            ("testLoadSimple", testLoadSimple),
            ("testLoadFile", testLoadFile),
            ("testLoadData", testLoadData)
        ]
    }

    func testLoadSimple() {
        // String
        var manager = ConfigurationManager()
        manager.load("Hello world")
        XCTAssertEqual(manager.getConfigs() as? String, "Hello world")

        // Array
        manager = ConfigurationManager()
        manager.load([0, "1", "hello world"])
        XCTAssertEqual(manager["2"] as? String, "hello world")

        // Dictionary
        manager = ConfigurationManager()
        manager.load(["Hello": "World"])
        XCTAssertEqual(manager["Hello"] as? String, "World")
    }

    func testLoadFile() {
        // JSON
        var manager = ConfigurationManager()

        do {
            try manager.load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
            XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        }
        catch {
            XCTFail("Cannot read file")
        }

        // PLIST
        manager = ConfigurationManager()

        do {
            try manager.load(file: "../../../TestResources/test.plist", relativeFrom: .customPath(#file))
            #if os(OSX)
                // broken on Linux due to https://bugs.swift.org/browse/SR-3681
                XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
            #endif
        }
        catch {
            XCTFail("Cannot read file")
        }

        // File does not exist
        manager = ConfigurationManager()

        XCTAssertThrowsError(try manager.load(file: "../../../TestResources/TheFileIsALie.json", relativeFrom: .customPath(#file)))
    }

    func testLoadData() {
        // JSON
        var manager = ConfigurationManager()
        let jsonString = "{\"hello\": \"world\"}"

        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Cannot convert \(jsonString) to Data")
            return
        }

        do {
            try manager.load(data: jsonData)
            XCTAssertEqual(manager["hello"] as? String, "world")
        }
        catch {
            XCTFail("Cannot load data")
        }

        // XML - not supported
        manager = ConfigurationManager()
        let xmlString = "<hello>world</hello>"

        guard let xmlData = xmlString.data(using: .utf8) else {
            XCTFail("Cannot convert \(xmlString) to Data")
            return
        }

        XCTAssertThrowsError(try manager.load(data: xmlData))
    }
}

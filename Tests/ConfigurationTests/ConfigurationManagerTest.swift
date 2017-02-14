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
        ]
    }

    func testLoadSimple() {
        var manager = ConfigurationManager()
        manager.load("Hello world")
        XCTAssertEqual(manager.getConfigs() as? String, "Hello world")

        manager = ConfigurationManager()
        manager.load([0, "1", "hello world"])
        XCTAssertEqual(manager["2"] as? String, "hello world")

        manager = ConfigurationManager()
        manager.load(["Hello": "World"])
        XCTAssertEqual(manager["Hello"] as? String, "World")
    }

    func testLoadFile() {
        // JSON
        var manager = ConfigurationManager()

        do {
            try manager.load(file: "../../../TestResources/default.json", relativeFrom: .customPath(#file))
            XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        }
        catch {
            XCTFail("Cannot read file")
        }

        // PLIST
        manager = ConfigurationManager()

        do {
            try manager.load(file: "../../../TestResources/default.plist", relativeFrom: .customPath(#file))
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

        XCTAssertThrowsError(try manager.load(file: "../../../TestResources/thisfileisalie.json", relativeFrom: .customPath(#file)))
    }
}

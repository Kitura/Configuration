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
import Foundation
import FileResolver
@testable import Configuration

class ConfigurationManagerTest: XCTestCase {
    static var allTests : [(String, (ConfigurationManagerTest) -> () throws -> Void)] {
        return [
            ("testLoadSimple", testLoadSimple),
            ("testLoadArgv", testLoadArgv),
            ("testLoadEnvVar", testLoadEnvVar),
            ("testLoadData", testLoadData),
            ("testLoadFile", testLoadFile),
            ("testLoadRelative", testLoadRelative)
        ]
    }

    static let testJSONURL = URL(fileURLWithPath: #file).appendingPathComponent("../test.json").standardized

    static let symlinkInPWD = URL(fileURLWithPath: "test.json")

    static let symlinkInExecutableFolder = URL(fileURLWithPath: FileResolver.executableFolder).appendingPathComponent("test.json").standardized

    let jsonString = "{\n    \"env\": \"<default>\",\n    \"OAuth\": {\n        \"name\": \"facebook\",\n        \"configuration\": {\n            \"clientID\": \"<default>\",\n            \"clientSecret\": \"<default>\",\n            \"profileFields\": [\"displayName\", \"emails\", \"id\", \"name\"],\n            \"profileURL\": \"https://graph.facebook.com/v2.6/me\",\n            \"scope\": [\"email\"],\n            \"state\": true\n        }\n    },\n    \"port\": \"<default>\"\n}"

    // Create symlink to test configuration file in PWD and executable folder
    override class func setUp() {
        do {
            try FileManager.default.createSymbolicLink(at: symlinkInPWD, withDestinationURL: testJSONURL)
        }
        catch {
            // Nothing we can do but leave a failure message
            print("Failed to create pwd symbolic link")
            print(error.localizedDescription)
        }

        do {
            try FileManager.default.createSymbolicLink(at: symlinkInExecutableFolder, withDestinationURL: testJSONURL)
        }
        catch {
            // Nothing we can do but leave a failure message
            print("Failed to create executable symbolic link")
            print(error.localizedDescription)
        }
    }

    // Delete test configuration file symlink created in setUp()
    override class func tearDown() {
        do {
            try FileManager.default.removeItem(at: symlinkInPWD)
        }
        catch {
            // Nothing we can do but leave a failure message
            XCTFail(error.localizedDescription)
        }

        do {
            try FileManager.default.removeItem(at: symlinkInExecutableFolder)
        }
        catch {
            // Nothing we can do but leave a failure message
            XCTFail(error.localizedDescription)
        }
    }

    func testLoadArgv() {
        // Set up CommandLine.arguments
        CommandLine.arguments.append("--argv=\(jsonString)")

        let manager = ConfigurationManager().load(.commandLineArguments)

        XCTAssertEqual(manager["argv:OAuth:configuration:state"] as? Bool, true)

        // Clean up CommandLine.arguments
        CommandLine.arguments.removeLast()
    }

    func testLoadEnvVar() {
        // Does not work in Linux yet due to https://bugs.swift.org/browse/SR-5076

        #if os(macOS)
            // Set env var
            XCTAssertEqual(setenv("ENV", jsonString, 1), 0)

            let manager = ConfigurationManager().load(.environmentVariables)

            XCTAssertEqual(manager["ENV:OAuth:configuration:state"] as? Bool, true)

            // Unset env var
            XCTAssertEqual(unsetenv("ENV"), 0)
        #endif
    }

    func testLoadSimple() {
        var manager: ConfigurationManager

        // String
        manager = ConfigurationManager().load("Hello world")
        XCTAssertEqual(manager.getConfigs() as? String, "Hello world")

        // Array
        manager = ConfigurationManager().load([0, "1", "hello world"])
        XCTAssertEqual(manager["2"] as? String, "hello world")

        // Dictionary
        manager = ConfigurationManager().load(["Hello": "World"])
        XCTAssertEqual(manager["Hello"] as? String, "World")
    }

    func testLoadData() {
        var manager: ConfigurationManager

        // JSON
        let jsonString = "{\"hello\": \"world\"}"

        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Cannot convert \(jsonString) to Data")
            return
        }

        manager = ConfigurationManager().load(data: jsonData)
        XCTAssertEqual(manager["hello"] as? String, "world")

        // PLIST
        let plistString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n<plist version=\"1.0\">\n<dict>\n\t<key>hello</key>\n\t<string>world</string>\n</dict>\n</plist>\n"

        guard let plistData = plistString.data(using: .utf8) else {
            XCTFail("Cannot convert \(plistString) to Data")
            return
        }

        manager = ConfigurationManager().load(data: plistData)
        XCTAssertEqual(manager["hello"] as? String, "world")
    }

    func testLoadFile() {
        var manager: ConfigurationManager

        // JSON
        manager = ConfigurationManager().load(file: "../test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // PLIST
        manager = ConfigurationManager().load(file: "../test.plist", relativeFrom: .customPath(#file))

        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
    }

    func testLoadRelative() {
        var manager: ConfigurationManager

        // Custom
        manager = ConfigurationManager().load(file: "../test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // PWD
        manager = ConfigurationManager().load(file: "test.json", relativeFrom: .pwd)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // Executable
        manager = ConfigurationManager().load(file: "test.json", relativeFrom: .executable)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
    }
}

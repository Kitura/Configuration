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
@testable import Configuration

class ConfigurationManagerTest: XCTestCase {
    static var allTests : [(String, (ConfigurationManagerTest) -> () throws -> Void)] {
        return [
            ("testLoadSimple", testLoadSimple),
            ("testLoadFile", testLoadFile),
            ("testLoadData", testLoadData),
            ("testLoadRelative", testLoadRelative),
            ("testExternalExecutable", testExternalExecutable)
        ]
    }

    static let testJSONURL = URL(fileURLWithPath: #file).appendingPathComponent("../../../TestResources/test.json").standardized

    static let symlinkToPWD = URL(fileURLWithPath: "test.json")

    let jsonString = "{\n    \"env\": \"<default>\",\n    \"OAuth\": {\n        \"name\": \"facebook\",\n        \"configuration\": {\n            \"clientID\": \"<default>\",\n            \"clientSecret\": \"<default>\",\n            \"profileFields\": [\"displayName\", \"emails\", \"id\", \"name\"],\n            \"profileURL\": \"https://graph.facebook.com/v2.6/me\",\n            \"scope\": [\"email\"],\n            \"state\": true\n        }\n    },\n    \"port\": \"<default>\"\n}"

    // Copy test resource files over to the correct locations for testing
    override class func setUp() {
        do {
            try FileManager.default.createSymbolicLink(at: symlinkToPWD, withDestinationURL: testJSONURL)
        }
        catch {
            // Nothing we can do but leave a failure message
            print(error)
        }
    }

    // Delete test resource files copied in setUp()
    override class func tearDown() {
        do {
            try FileManager.default.removeItem(at: symlinkToPWD)
        }
        catch {
            // Nothing we can do but leave a failure message
            print(error)
        }
    }

    // Helper function to run shell commands
    // Tip from http://stackoverflow.com/a/26973384
    func shell(_ args: String..., environment: [String: String] = [:]) -> (Pipe, Pipe, Int32) {
        #if os(Linux)
            let process = Task()
        #else
            let process = Process()
        #endif

        let errPipe = Pipe()
        let outPipe = Pipe()
        process.launchPath = "/usr/bin/env"
        process.arguments = args
        process.environment = environment
        process.standardError = errPipe
        process.standardOutput = outPipe

        process.launch()
        process.waitUntilExit()

        return (errPipe, outPipe, process.terminationStatus)
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

    func testLoadFile() {
        var manager: ConfigurationManager

        // JSON
        manager = ConfigurationManager().load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // PLIST
        manager = ConfigurationManager().load(file: "../../../TestResources/test.plist", relativeFrom: .customPath(#file))

        #if swift(>=4)
            // Broken on Linux due to https://bugs.swift.org/browse/SR-3681
            XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        #else
            XCTAssertEqual(manager["OAuth:configuration:scope:0"] as? String, "email")
        #endif
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

    func testLoadRelative() {
        var manager: ConfigurationManager

        manager = ConfigurationManager().load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager().load(file: "test.json", relativeFrom: .pwd)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // .executable and .project are tested in TestProgram
    }

    func testExternalExecutable() {
        let projectFolder = URL(fileURLWithPath: #file).appendingPathComponent("../../../").standardized
        let testProgramURL = projectFolder.appendingPathComponent(".build/debug/TestProgram").standardized

        var (errPipe, outPipe, exitCode): (Pipe, Pipe, Int32)
        var output: String?, error: String?

        #if os(Linux)
            guard FileManager.default.fileExists(atPath: testProgramURL.path) else {
                XCTFail("Test executable does not exist")
                return
            }

            // Not possible to `swift build` in project folder because this test is
            // ran from .build directory on Linux
        #else
            // Force rebuild of test executable on OSX
            (errPipe, outPipe, exitCode) = shell("swift", "build", "-C", projectFolder.path)
            output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)

            print(output ?? "No stdout from `swift build -C \(projectFolder.path)`")

            guard exitCode == 0 else {
                XCTFail("Unable to build project")
                return
            }
        #endif

        // Run the test executable
        (errPipe, outPipe, exitCode) = shell(testProgramURL.path, "--argv=\(jsonString)", environment: ["ENV": jsonString])

        output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)

        print(output ?? "No stdout from test executable")

        XCTAssertEqual(exitCode, 0, "One or more external load assertions failed")
        XCTAssertEqual(error, "", "External load test has non-empty error stream: \(error)")
    }
}

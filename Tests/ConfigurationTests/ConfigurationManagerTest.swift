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
            ("testLoadArgv", testLoadArgv),
            ("testLoadEnvVar", testLoadEnvVar),
            ("testLoadData", testLoadData),
            ("testLoadFile", testLoadFile),
            ("testLoadRelative", testLoadRelative),
            ("testExternalExecutable", testExternalExecutable)
        ]
    }

    static let testJSONURL = URL(fileURLWithPath: #file).appendingPathComponent("../test.json").standardized

    static let symlinkToPWD = URL(fileURLWithPath: "test.json")

    let jsonString = "{\n    \"env\": \"<default>\",\n    \"OAuth\": {\n        \"name\": \"facebook\",\n        \"configuration\": {\n            \"clientID\": \"<default>\",\n            \"clientSecret\": \"<default>\",\n            \"profileFields\": [\"displayName\", \"emails\", \"id\", \"name\"],\n            \"profileURL\": \"https://graph.facebook.com/v2.6/me\",\n            \"scope\": [\"email\"],\n            \"state\": true\n        }\n    },\n    \"port\": \"<default>\"\n}"

    // Create symlink to test configuration file in PWD
    override class func setUp() {
        do {
            try FileManager.default.createSymbolicLink(at: symlinkToPWD, withDestinationURL: testJSONURL)
        }
        catch {
            // Nothing we can do but leave a failure message
            XCTFail(error.localizedDescription)
        }
    }

    // Delete test configuration file symlink created in setUp()
    override class func tearDown() {
        do {
            try FileManager.default.removeItem(at: symlinkToPWD)
        }
        catch {
            // Nothing we can do but leave a failure message
            XCTFail(error.localizedDescription)
        }
    }

    // Helper function to run shell commands
    // Tip from http://stackoverflow.com/a/26973384
    func shell(_ args: String...,
        currentDirectoryPath: String = presentWorkingDirectory,
        environment: [String: String] = [:]) -> (Pipe, Pipe, Int32) {
        // Print out the command to be executed
        var command = "/usr/bin/env"

        args.forEach { command.append(" " + $0) }
        print("Executing command: \(String(describing: command))")

        #if os(Linux) && !swift(>=3.1)
            typealias Process = Task
        #endif

        // Configure the Process instance
        let process = Process()
        let errPipe = Pipe()
        let outPipe = Pipe()
        process.arguments = args
        process.currentDirectoryPath = currentDirectoryPath
        process.environment = environment
        process.launchPath = "/usr/bin/env"
        process.standardError = errPipe
        process.standardOutput = outPipe

        // Execute the Process instance
        process.launch()
        process.waitUntilExit()

        return (errPipe, outPipe, process.terminationStatus)
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

        #if swift(>=4)
            // Broken on Linux due to https://bugs.swift.org/browse/SR-3681
            XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        #else
            XCTAssertEqual(manager["OAuth:configuration:scope:0"] as? String, "email")
        #endif
    }

    func testLoadRelative() {
        var manager: ConfigurationManager

        manager = ConfigurationManager().load(file: "../test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager().load(file: "test.json", relativeFrom: .pwd)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // .executable and .project are tested in TestProgram
    }

    func testExternalExecutable() {
        let projectFolder = URL(fileURLWithPath: #file).appendingPathComponent("../../../").standardized
        let testProgramURL = projectFolder.appendingPathComponent(".build/debug/ConfigurationTestExecutable").standardized

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

            // Need to pass in current environment variables on local machine or it will fail with
            // `error: Unable to find executable for 'xcrun'`
            // when ran with Xcode 9 beta
            (errPipe, outPipe, exitCode) = shell("swift", "build",
                                                 currentDirectoryPath: projectFolder.path,
                                                 environment: ProcessInfo.processInfo.environment)
            output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)

            print(output ?? "No stdout from `swift build`")

            guard exitCode == 0 else {
                let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
                XCTFail(error ?? "No stderr from `swift build`")
                return
            }
        #endif

        // Run the test executable
        (errPipe, outPipe, exitCode) = shell(testProgramURL.path, environment: ["ENV": jsonString])

        output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)

        print(output ?? "No stdout from test executable")

        XCTAssertEqual(exitCode, 0, "One or more external load assertions failed")
        XCTAssertEqual(error, "", "External load test has non-empty error stream: \(String(describing: error))")
    }
}

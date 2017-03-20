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

let jsonString = "{\n    \"env\": \"<default>\",\n    \"OAuth\": {\n        \"name\": \"facebook\",\n        \"configuration\": {\n            \"clientID\": \"<default>\",\n            \"clientSecret\": \"<default>\",\n            \"profileFields\": [\"displayName\", \"emails\", \"id\", \"name\"],\n            \"profileURL\": \"https://graph.facebook.com/v2.6/me\",\n            \"scope\": [\"email\"],\n            \"state\": true\n        }\n    },\n    \"port\": \"<default>\"\n}"

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

    static let symlinkToExecutableFolder = URL(fileURLWithPath: ConfigurationManager.BasePath.executable.path).appendingPathComponent("test.json").standardized

    // Copy test resource files over to the correct locations for testing
    override class func setUp() {
        do {
            try FileManager.default.createSymbolicLink(at: symlinkToPWD, withDestinationURL: testJSONURL)
//            try FileManager.default.createSymbolicLink(at: symlinkToExecutableFolder, withDestinationURL: testJSONURL)
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
//            try FileManager.default.removeItem(at: symlinkToExecutableFolder)
        }
        catch {
            // Nothing we can do but leave a failure message
            print(error)
        }
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

        // Currently breaking, skip for now
        //        manager = ConfigurationManager()(file: "TestResources/test.json", relativeFrom: .project)
        //        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        //
        //        manager = ConfigurationManager().load(file: "../../TestResources/test.json", relativeFrom: .executable)
        //        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        //
        //        manager = ConfigurationManager()

        manager = ConfigurationManager().load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager().load(file: "test.json", relativeFrom: .pwd)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
    }

    func testExternalExecutable() {
        #if os(Linux)
            let testProgramURL = executableFolderURL.appendingPathComponent("TestProgram")
        #else
            let xctestBundles = Bundle.allBundles.filter({ $0.bundlePath.hasSuffix(".xctest") })

            guard xctestBundles.count > 0 else {
                XCTFail("No xctest bundle found")
                return
            }

            let testProgramURL = xctestBundles[0].bundleURL.appendingPathComponent("../TestProgram")
        #endif

        #if os(Linux)
            let process = Task()
        #else
            let process = Process()
        #endif

        let errPipe = Pipe()
        let outPipe = Pipe()
        process.launchPath = testProgramURL.path
        process.arguments = ["--argv=" + jsonString]
        process.environment = ["ENV": jsonString]
        process.standardError = errPipe
        process.standardOutput = outPipe
        process.launch()

        let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        process.waitUntilExit()

        print(output ?? "No stdout from test executable")

        XCTAssertEqual(process.terminationStatus, 0, "One or more external load assertions failed")
        XCTAssertEqual(error, "", "External load test has non-empty error stream: \(error)")
    }
}

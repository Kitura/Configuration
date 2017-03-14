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
            ("testLoadRelativeExternal", testLoadRelativeExternal)
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

        manager.load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        // PLIST
        manager = ConfigurationManager()

        manager.load(file: "../../../TestResources/test.plist", relativeFrom: .customPath(#file))

        #if swift(>=4)
            // Broken on Linux due to https://bugs.swift.org/browse/SR-3681
            XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
        #else
            XCTAssertEqual(manager["OAuth:configuration:scope:0"] as? String, "email")
        #endif
    }

    func testLoadData() {
        // JSON
        let manager = ConfigurationManager()
        let jsonString = "{\"hello\": \"world\"}"

        guard let jsonData = jsonString.data(using: .utf8) else {
            XCTFail("Cannot convert \(jsonString) to Data")
            return
        }

        manager.load(data: jsonData)
        XCTAssertEqual(manager["hello"] as? String, "world")
    }

    func testLoadRelative() {
        var manager = ConfigurationManager()
        manager.load(file: "TestResources/test.json", relativeFrom: .project)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager()
        manager.load(file: "../../TestResources/test.json", relativeFrom: .executable)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager()
        manager.load(file: "../../../TestResources/test.json", relativeFrom: .customPath(#file))
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)

        manager = ConfigurationManager()
        guard FileManager().changeCurrentDirectoryPath(executableFolder + "/..") else {
            XCTFail("Failed to set working directory")
            return
        }
        manager.load(file: "../TestResources/test.json", relativeFrom: .pwd)
        XCTAssertEqual(manager["OAuth:configuration:state"] as? Bool, true)
    }

    func testLoadRelativeExternal() {
        func execute(_ file: URL) -> (Int32, String, String) {
            #if os(Linux)
                let process = Task()
            #else
                let process = Process()
            #endif
            let errPipe = Pipe()
            let outPipe = Pipe()
            process.launchPath = file.path
            process.arguments = []
            process.standardError = errPipe
            process.standardOutput = outPipe
            process.launch()

            let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            let error = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
            process.waitUntilExit()

            return (process.terminationStatus, error ?? "", output ?? "")
        }
        let externalTestExecutable = URL(fileURLWithPath: executableFolder).appendingPathComponent("TestProgram");
        let (exitCode, error, output) = execute(externalTestExecutable);
        XCTAssertEqual(exitCode, 0, "One or more external load assertions failed")
        XCTAssertEqual(error, "", "External load test has non-empty error stream: \(error)")
        XCTAssert(output.contains(".project: PASS"), "External load test .project assertion failed");
        XCTAssert(output.contains(".executable: PASS"), "External load test .executable assertion failed");
        XCTAssert(output.contains(".customPath: PASS"), "External load test .customPath assertion failed");
        XCTAssert(output.contains(".pwd: PASS"), "External load test .pwd assertion failed");
    }
}

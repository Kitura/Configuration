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

import Foundation
import LoggerAPI

// This URL is pointing to the executable, always
private let executableURL = { () -> URL in
    #if os(Linux)
        // Bundle is not available on Linux yet
        // Get path to executable via /proc/self/exe
        // https://unix.stackexchange.com/questions/333225/which-process-is-proc-self-for
        return URL(fileURLWithPath: "/proc/self/exe")
    #else
        // Bundle is available on Darwin
        return (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
    #endif
    }().resolvingSymlinksInPath()

// This URL points to this source file
private let sourceFileURL = URL(fileURLWithPath: #file)

// When program is ran from inside Xcode, the executable's path contains /DerivedData
private let isRanInsideXcode = executableURL.path.range(of: "/DerivedData/") != nil

// When code is executed from within XCTestCase in Xcode, the executable is xctest
private let isRanFromXCTest = executableURL.path.hasSuffix("/xctest")

/// Directory containing the executable of the project, or, if run from inside Xcode,
/// the /.build/debug folder in the project's root folder.
private let executableFolderURL = { () -> URL in
    if isRanInsideXcode || isRanFromXCTest {
        // Get URL to /debug manually
        let sourceFile = sourceFileURL.path

        if let range = sourceFile.range(of: "/checkouts/") {
            // In Swift 3.1, package source code is downloaded to /<build-path>/checkouts
            #if swift(>=3.2)
                return URL(fileURLWithPath: sourceFile[..<range.lowerBound] + "/debug")
            #else
                return URL(fileURLWithPath: sourceFile.substring(to: range.lowerBound) + "/debug")
            #endif
        }
        else if let range = sourceFile.range(of: "/Packages/") {
            // In Swift 3.0-3.0.2 (or editable package in Swift 3.1), package source code is downloaded to /Packages
            // Since we don't know /<build-path>, assume /.build instead
            #if swift(>=3.2)
                return URL(fileURLWithPath: sourceFile[..<range.lowerBound] + "/.build/debug")
            #else
                return URL(fileURLWithPath: sourceFile.substring(to: range.lowerBound) + "/.build/debug")
            #endif
        }

        Log.warning("Cannot infer /.build/debug folder location from source code structure. Using executable folder as determined from inside Xcode.")
    }

    return executableURL.appendingPathComponent("..")
    }().standardized

// Takes a starting directory and iterates down the tree to find package.swift (the root directory)
private let projectHeadIterator = { (startingDir: URL) -> URL? in
    let fileManager = FileManager()
    var startingDir = startingDir.appendingPathComponent("dummy")

    repeat {
        startingDir.appendPathComponent("..")
        startingDir.standardize()
        let packageFilePath = startingDir.appendingPathComponent("Package.swift").path

        if fileManager.fileExists(atPath: packageFilePath) {
            return startingDir
        }
    } while startingDir.path != "/"

    return nil
}
/// Directory containing the Package.swift of the project (as determined by traversing
/// up the directory structure starting at the directory containing the executable), or
/// if no Package.swift is found then the directory containing the executable
private let projectFolderURL = { () -> URL in
    guard let url = projectHeadIterator(executableFolderURL) else {
        Log.warning("No Package.swift found. Using executable folder as project folder.")
        return executableFolderURL
    }

    return url

}().standardized

/// Directory containing the Package.swift of the project when run through XCode or XCTest
/// Otherwise, returns the current working directory
let presentWorkingDirectoryURL = { () -> URL in
    guard isRanInsideXcode || isRanFromXCTest, let url = projectHeadIterator(sourceFileURL) else {
        return URL(fileURLWithPath: "")
    }

    Log.warning("Running from Xcode or XcTest. Using project folder as pwd folder.")

    return url

}().standardized

/// Absolute path to the executable's folder
let executableFolder = executableFolderURL.path

/// Absolute path to the project's root folder
let projectFolder = projectFolderURL.path

/// Absolute path to the present working directory (PWD)
let presentWorkingDirectory = presentWorkingDirectoryURL.path

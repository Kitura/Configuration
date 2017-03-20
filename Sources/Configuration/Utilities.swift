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

let executableFolderURL = { () -> URL in
    #if os(Linux)
        // Bundle is not available on Linux yet
        // Get path to exe via /proc/self/exe
        // https://unix.stackexchange.com/questions/333225/which-process-is-proc-self-for
        return URL(fileURLWithPath: "/proc/self/exe").resolvingSymlinksInPath().appendingPathComponent("..")
    #else
        // Bundle is available on Darwin
        return (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).appendingPathComponent("..")
    #endif
    }().standardized

/// Absolute path to the executable's folder
let executableFolder = executableFolderURL.path

/// Directory containing the Package.swift of the project (as determined by traversing
/// up the directory structure starting at the directory containing the executable), or
/// if no Package.swift is found then the directory containing the executable
let projectDirectory = { () -> String in
    let fileManager = FileManager()
    var directory = executableFolderURL.appendingPathComponent("dummy")

    repeat {
        directory.appendPathComponent("..")
        directory.standardize()
        let packageFilePath = directory.appendingPathComponent("Package.swift").path

        if fileManager.fileExists(atPath: packageFilePath) {
            return directory.path
        }
    } while directory.path != "/"

    return executableFolder
}()

/// Absolute path to the present working directory (PWD)
let presentWorkingDirectory = URL(fileURLWithPath: "").path

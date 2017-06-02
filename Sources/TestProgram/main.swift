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

// This executable is needed to test features of this package that relates to
// an executable (for example, loading a file relative to the project root),
// as well as features related to environment variables. None of these can be
// tested normally in Xcode and are instead being tested in this module that is
// only meant to be called from the unit tests.

// DO NOT RUN THIS PROGRAM FROM INSIDE XCODE.

import Foundation
import Configuration

var exitCode: Int32 = 0
var testsExecuted: Int32 = 0

var manager: ConfigurationManager

// test load env
manager = ConfigurationManager().load(.environmentVariables)

if manager["ENV:OAuth:configuration:state"] as? Bool == true {
    print("Test Case '-[.environmentVariables]': PASS")
}
else {
    print("Test Case '-[.environmentVariables]': FAIL")
    exitCode += 1 << testsExecuted
}

testsExecuted += 1

// test load file relative from executable
manager = ConfigurationManager().load(file: "../../Tests/ConfigurationTests/test.json", relativeFrom: .executable)

if manager["OAuth:configuration:state"] as? Bool == true {
    print("Test Case '-[.executable]': PASS")
}
else {
    print("Test Case '-[.executable]': FAIL")
    exitCode += 1 << testsExecuted
}

testsExecuted += 1

// test load file relative from project folder
manager = ConfigurationManager().load(file: "Tests/ConfigurationTests/test.json", relativeFrom: .project)

if manager["OAuth:configuration:state"] as? Bool == true {
    print("Test Case '-[.project]': PASS")
}
else {
    print("Test Case '-[.project]': FAIL")
    exitCode += 1 << testsExecuted
}

testsExecuted += 1

exit(exitCode)

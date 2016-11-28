/*
 * Copyright IBM Corporation 2016
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
@testable import SwiftConfiguration

class EnvironmentVariablesTest: XCTestCase {
    static var allTests : [(String, (EnvironmentVariablesTest) -> () throws -> Void)] {
        return [
            ("testEnvironmentVariables", testEnvironmentVariables),
        ]
    }

    func testEnvironmentVariables() {
        let configManager = ConfigurationManager()
        configManager.loadEnvironmentVariables(separator: "_")
        print(configManager.getConfigs())
    }
}

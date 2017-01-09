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

import Foundation

public class ConfigurationManager {
    /// Internal tree representation of all config values
    var root = ConfigurationNode.null

    public init() {}

    // values are added in this format:
    // <keyPrefix><path>=<value>
    @discardableResult
    public func loadCommandlineArguments(keyPrefix: String = "--", separator: String = ".") -> ConfigurationManager {
        let argv = CommandLine.arguments

        // skip first since it's always the executable
        for index in 1..<argv.count {
            // check if arg starts with keyPrefix
            if let prefixRange = argv[index].range(of: keyPrefix), prefixRange.lowerBound == argv[index].startIndex {
                if let breakRange = argv[index].range(of: "=") {
                    let path = argv[index][prefixRange.upperBound..<breakRange.lowerBound].replacingOccurrences(of: separator, with: ConfigurationNode.separator)
                    let value = argv[index].substring(from: breakRange.upperBound)

                    root[path] = ConfigurationNode(rawValue: value)
                }
            }
        }

        return self
    }

    @discardableResult
    public func loadEnvironmentVariables(separator: String = "__") -> ConfigurationManager {
        let envVars = ProcessInfo.processInfo.environment

        for (key, value) in envVars {
            let index = key.replacingOccurrences(of: separator, with: ConfigurationNode.separator)

            root[index] = ConfigurationNode(rawValue: value)
        }

        return self
    }

    @discardableResult
    public func loadFile(_ fileName: String) throws -> ConfigurationManager {
        // get NSString representation to access some path APIs
        let fn = NSString(string: fileName)
        let pathURL: URL

        if fn.isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            pathURL = URL(fileURLWithPath: executableRelativePath).appendingPathComponent(fileName)
        }

        let data = try Data(contentsOf: pathURL)

        // Only accept JSON dictionaries, not JSON raw values (not even raw arrays)
        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root.merge(overwrittenBy: ConfigurationNode(rawValue: dict))
        }

        return self
    }

    @discardableResult
    public func loadDictionary(_ dict: [String: Any]) -> ConfigurationManager {
        root.merge(overwrittenBy: ConfigurationNode(rawValue: dict))

        return self
    }

    public func getValue(for path: String) -> Any? {
        return root[path]?.rawValue
    }

    public func setValue(for path: String, as value: Any) {
        root[path] = ConfigurationNode(rawValue: value)
    }

    public func getConfigs() -> Any? {
        return root.rawValue
    }
}

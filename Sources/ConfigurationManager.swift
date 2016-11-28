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
    let root = ConfigurationNode()

    public init() {}

    public func loadCommandlineArguments(keyPrefix: String = "--", separator: String = "__") {
        // drop first since it's always the executable
        let argv = CommandLine.arguments.dropFirst()
        var index = 0

        while index + 1 < argv.count {
            if let range = argv[index].range(of: keyPrefix),
                range.lowerBound == argv[index].startIndex {
                let key = argv[index].replacingOccurrences(of: separator, with: ConfigurationNode.separator)

                guard let _ = root[key] else {
                    root[key] = ConfigurationNode(rawValue: argv[index + 1])
                    index = index + 2
                    continue
                }
            }

            index = index + 1
        }
    }

    public func loadEnvironmentVariables(separator: String = "__") {
        let envVars = ProcessInfo.processInfo.environment
        print(envVars)

        for (key, value) in envVars {
            let index = key.replacingOccurrences(of: separator, with: ConfigurationNode.separator)

            guard let _ = root[index] else {
                root[index] = ConfigurationNode(rawValue: value)
                continue
            }
        }
    }

    public func loadFile(_ fileName: String, fileType: FileType? = nil) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: fileName))

        // Only accept JSON dictionaries, not JSON raw values (not even arrays)
        if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
            root.merge(overwrite: ConfigurationNode(rawValue: dict))
        }
    }

    public func loadDictionary(_ dict: [String: Any]) {
        root.merge(overwrite: ConfigurationNode(rawValue: dict))
    }

    public func getValue(for key: String) -> Any? {
        return root[key]?.rawValue
    }

    public func setValue(for key: String, as value: Any) {
        root[key] = ConfigurationNode(rawValue: value)
    }

    public func getConfigs() -> Any? {
        return root.rawValue
    }
}

public enum FileType: String {
    case JSON = "json"
}

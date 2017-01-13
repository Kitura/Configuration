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

public class ConfigurationManager {
    /// Internal tree representation of all config values
    var root = ConfigurationNode.dictionary([:])

    public init() {}

    // values are added in this format:
    // <keyPrefix><path>=<value>
    @discardableResult
    public func loadCommandlineArguments(keyPrefix: String = "--", separator: String = ".") -> ConfigurationManager {
        let argv = CommandLine.arguments

        // skip first since it's always the executable
        for index in 1..<argv.count {
            // check if arg starts with keyPrefix
            if let prefixRange = argv[index].range(of: keyPrefix),
                prefixRange.lowerBound == argv[index].startIndex,
                let breakRange = argv[index].range(of: "=") {
                let path = argv[index][prefixRange.upperBound..<breakRange.lowerBound].replacingOccurrences(of: separator, with: ConfigurationNode.separator)
                let value = argv[index].substring(from: breakRange.upperBound)

                root[path] = ConfigurationNode(rawValue: value)
            }
        }

        return self
    }

    @discardableResult
    public func loadDictionary(_ dict: [String: Any]) -> ConfigurationManager {
        root.merge(overwrittenBy: ConfigurationNode(rawValue: dict))

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
    public func loadFile(_ fileName: String, relativeFrom: String = executableFolderAbsolutePath) throws -> ConfigurationManager {
        // get NSString representation to access some path APIs like `isAbsolutePath`
        // and `expandingTildeInPath`
        let fn = NSString(string: fileName)
        let pathURL: URL

        if fn.isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            pathURL = URL(fileURLWithPath: relativeFrom).appendingPathComponent(fileName).standardized
        }

        let data = try Data(contentsOf: pathURL)

        // default to JSON parsing
        var type = DataType.JSON
        let fullPath = pathURL.standardized.absoluteString

        if let range = fullPath.range(of: ".", options: String.CompareOptions.backwards) {
            type = DataType(fullPath.substring(from: range.lowerBound)) ?? DataType.JSON
        }

        if let dict = try deserialize(data: data, type: type) {
            print(dict)
            self.loadDictionary(dict)
        }

        return self
    }

    @discardableResult
    public func loadRemoteResource(_ urlString: String) throws -> ConfigurationManager {
        guard let url = URL(string: urlString) else {
            return self
        }

        // help from http://stackoverflow.com/a/31563134
        // in order to make dataTask synchronous
        let request = URLRequest(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var dataOptional: Data? = nil
        var httpResponseOptional: HTTPURLResponse? = nil
        var errorOptional: Error? = nil

        URLSession.shared.dataTask(with: request) { (responseData, response, error) -> Void in
            dataOptional = responseData
            httpResponseOptional = response as? HTTPURLResponse
            errorOptional = error
            semaphore.signal()
            }.resume()

        let _ = semaphore.wait(timeout: .distantFuture)

        if let error = errorOptional {
            throw error
        }

        guard let httpResponse = httpResponseOptional,
            let data = dataOptional,
            let type = httpResponse.allHeaderFields["Content-Type"] as? String else {
                return self
        }

        if type.hasPrefix("application/json"),
            let dict = try deserialize(data: data, type: .JSON) {
            self.loadDictionary(dict)
        }

        return self
    }

    public func getConfigs() -> Any {
        return root.rawValue
    }

    public subscript(path: String) -> Any? {
        get {
            return root[path]?.rawValue
        }
        set {
            guard let rawValue = newValue else {
                return
            }

            root[path] = ConfigurationNode(rawValue: rawValue)
        }
    }
}

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

/// ConfigurationManager class
///
/// One-stop shop to aggregate configuration properties from different sources,
/// including commandline arguments, environment variables, files, remove resources,
/// and raw objects.
public class ConfigurationManager {
    /// Internal tree representation of all config values
    private var root = ConfigurationNode.dictionary([:])

    /// Defaults to `--`
    public var commandLineArgumentKeyPrefix: String

    /// Defaults to `.`
    public var commandLineArgumentPathSeparator: String

    /// Defaults to `__`
    public var environmentVariablePathSeparator: String

    public enum Source {
        case CommandLineArguments
        case EnvironmentVariables
    }

    /// Constructor
    /// - parameter commandLineArgumentKeyPrefix: Optional. Used to denote an argument
    /// as a configuration path-value pair. Defaults to `--`.
    /// - parameter commandLineArgumentPathSeparator: Optional. Used to separate the
    /// components of a path. Defaults to `.`.
    /// - parameter environmentVariablePathSeparator: Optional. Used to separate the
    /// components of a path. Defaults to `__`.
    public init(commandLineArgumentKeyPrefix: String = "--",
                commandLineArgumentPathSeparator: String = ".",
                environmentVariablePathSeparator: String = "__") {
        self.commandLineArgumentKeyPrefix = commandLineArgumentKeyPrefix
        self.commandLineArgumentPathSeparator = commandLineArgumentPathSeparator
        self.environmentVariablePathSeparator = environmentVariablePathSeparator
    }

    /// Load configurations from raw object.
    /// - parameter object: The configurations object.
    @discardableResult
    public func load(_ object: Any) -> ConfigurationManager {
        root.merge(overwrittenBy: ConfigurationNode(rawValue: object))

        return self
    }

    /// Load configurations from command line arguments or environment variables.
    /// For command line arguments, the configurations are parsed from arguments
    /// in this format: `<keyPrefix><path>=<value>`
    /// - parameter source: Enum denoting which source to load from.
    @discardableResult
    public func load(_ source: Source) -> ConfigurationManager {
        switch source {
        case .CommandLineArguments:
            let argv = CommandLine.arguments

            // skip first since it's always the executable
            for index in 1..<argv.count {
                // check if arg starts with keyPrefix
                if let prefixRange = argv[index].range(of: commandLineArgumentKeyPrefix),
                    prefixRange.lowerBound == argv[index].startIndex,
                    let breakRange = argv[index].range(of: "=") {
                    let path = argv[index][prefixRange.upperBound..<breakRange.lowerBound]
                        .replacingOccurrences(of: commandLineArgumentPathSeparator,
                                              with: ConfigurationNode.separator)
                    let value = argv[index].substring(from: breakRange.upperBound)

                    root[path] = ConfigurationNode(rawValue: value)
                }
            }
        case .EnvironmentVariables:
            ProcessInfo.processInfo.environment.forEach {
                let index = $0.replacingOccurrences(of: environmentVariablePathSeparator,
                                                    with: ConfigurationNode.separator)

                root[index] = ConfigurationNode(rawValue: $1)
            }
        }

        return self
    }

    /// Load configurations from a file on system.
    /// - parameter fileName: Path to file.
    /// - parameter relativeFrom: Optional. Defaults to the location of the executable.
    @discardableResult
    public func load(file: String, relativeFrom: String = executableFolderAbsolutePath) throws -> ConfigurationManager {
        // get NSString representation to access some path APIs like `isAbsolutePath`
        // and `expandingTildeInPath`
        let fn = NSString(string: file)
        let pathURL: URL

        if fn.isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            pathURL = URL(fileURLWithPath: relativeFrom).appendingPathComponent(file).standardized
        }

        let data = try Data(contentsOf: pathURL)

        // default to JSON parsing
        var type = DataType.JSON
        let fullPath = pathURL.standardized.absoluteString

        if let range = fullPath.range(of: ".", options: String.CompareOptions.backwards) {
            type = DataType(fullPath.substring(from: range.lowerBound)) ?? type
        }

        return self.load(try deserialize(data: data, type: type))
    }

    /// Load configurations from a remote location.
    /// - parament urlString: The URL pointing to a remote location as a string.
    @discardableResult
    public func load(remoteURL: String) throws -> ConfigurationManager {
        guard let url = URL(string: remoteURL) else {
            return self
        }

        // Help from http://stackoverflow.com/a/31563134
        // in order to make dataTask synchronous
        let request = URLRequest(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var dataOptional: Data? = nil
        var httpResponseOptional: HTTPURLResponse? = nil
        var errorOptional: Error? = nil

        URLSession.shared.dataTask(with: request) { responseData, response, error in
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

        if type.hasPrefix("application/json") {
            // Assume JSON format
            self.load(try deserialize(data: data, type: .JSON))
        }

        return self
    }

    /// Get all configurations merged in the manager as a raw object.
    public func getConfigs() -> Any {
        return root.rawValue
    }

    /// Access configurations by paths.
    /// - parameter path: The path to a configuration value.
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

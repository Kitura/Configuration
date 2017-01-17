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
        case commandLineArguments
        case environmentVariables
    }

    /// Supported data types
    public enum DataType {
        case json
        case plist

        init?(fileExtension: String) {
            switch fileExtension.lowercased() {
            case ".json":
                self = .json
            case ".plist":
                self = .plist
            default:
                return nil
            }
        }

        init?(mimeType: String) {
            let type = mimeType.lowercased()

            if type.hasSuffix("/json") {
                self = .json
            }
            else {
                return nil
            }
        }
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
        case .commandLineArguments:
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
        case .environmentVariables:
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
    public func load(file: String,
                     relativeFrom: String = executableFolderAbsolutePath) throws
        -> ConfigurationManager {
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

        return try self.load(url: pathURL)
    }

    /// Load configurations from a remote location.
    /// - parameter url: The URL pointing to a configuration resource.
    /// - parameter type: Optional. The type of data at the configuration resource.
    /// Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e., `.json`; otherwise, parser will attempt to determine
    /// the correct format, which isn't always reliable.
    @discardableResult
    public func load(url: URL, type: DataType? = nil) throws -> ConfigurationManager {
        // Help from http://stackoverflow.com/a/31563134
        // in order to make dataTask synchronous
        let request = URLRequest(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        var dataOptional: Data? = nil
        var responseOptional: URLResponse? = nil
        var errorOptional: Error? = nil

        URLSession.shared.dataTask(with: request) { responseData, response, error in
            dataOptional = responseData
            responseOptional = response
            errorOptional = error
            semaphore.signal()
            }.resume()

        let _ = semaphore.wait(timeout: .distantFuture)

        if let error = errorOptional {
            throw error
        }

        guard let data = dataOptional else {
                return self
        }

        // figure out what is the data type

        // default to JSON
        var dataType = DataType.json

        if url.isFileURL{
            // check file extension for file type
            let fullPath = url.standardized.absoluteString

            if let range = fullPath.range(of: ".", options: .backwards) {
                dataType = DataType(fileExtension: fullPath.substring(from: range.lowerBound)) ?? dataType
            }
        }
        else if let mimeType = responseOptional?.mimeType?.lowercased() {
            // check for supported media types among the ones listed here:
            // https://www.iana.org/assignments/media-types/media-types.xhtml
            if mimeType.hasSuffix("/json") {
                dataType = .json
            }
        }

        dataType = type ?? dataType

        return self.load(try deserialize(data: data, type: dataType))
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

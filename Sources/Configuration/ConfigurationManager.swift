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

/// ConfigurationManager class
///
/// One-stop shop to aggregate configuration properties from different sources,
/// including commandline arguments, environment variables, files, remove resources,
/// and raw objects.
public class ConfigurationManager {
    // URLSession.shared isn't supported on Linux yet
    private let session = URLSession(configuration: URLSessionConfiguration.default)

    /// Internal tree representation of all config values
    private var root = ConfigurationNode.dictionary([:])

    /// List of known deserializers for parsing raw data (i.e., from file or HTTP requests)
    private var deserializers: [String: Deserializer] = [
        JSONDeserializer.shared.name: JSONDeserializer.shared,
        PLISTDeserializer.shared.name: PLISTDeserializer.shared
    ]

    /// Defaults to `--`
    public var commandLineArgumentKeyPrefix: String

    /// Defaults to `.`
    public var commandLineArgumentPathSeparator: String

    /// Defaults to `__`
    public var environmentVariablePathSeparator: String

    /// Defaults to `true`
    public var parseStringToObject: Bool

    /// Enum to specify configuration source between commandline arguments
    /// and environment variables.
    public enum Source {
        /// Flag to load configurations from commandline arguments
        case commandLineArguments

        /// Flag to load configurations from environment variables
        case environmentVariables
    }

    /// Base paths for resolving relative paths
    public enum BasePath {
        /// Relative from executable location
        case executable

        /// Relative from project directory
        case project

        /// Relative from present working directory (PWD)
        case pwd

        /// Relative from a custom location
        case customPath(String)

        /// Get the absolute path as denoted by self
        public var path: String {
            switch self {
            case .executable:
                return executableFolder
            case .pwd:
                return presentWorkingDirectory
            case .project:
                return projectFolder
            case .customPath(let path):
                return path
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
    /// - parameter parseStringToObject: Optional. Used to indicate if string values
    /// in commandline arguments and environment variables should be parsed to array
    /// or dictionary, if possible, using a known `Deserializer`. Defaults to `true`.
    public init(commandLineArgumentKeyPrefix: String = "--",
                commandLineArgumentPathSeparator: String = ".",
                environmentVariablePathSeparator: String = "__",
                parseStringToObject: Bool = true) {
        self.commandLineArgumentKeyPrefix = commandLineArgumentKeyPrefix
        self.commandLineArgumentPathSeparator = commandLineArgumentPathSeparator
        self.environmentVariablePathSeparator = environmentVariablePathSeparator
        self.parseStringToObject = parseStringToObject
    }

    /// Load configurations from raw object.
    /// - parameter object: The configurations object.
    @discardableResult
    public func load(_ object: Any) -> ConfigurationManager {
        Log.debug("Loading object: \(object)")

        root.merge(overwrittenBy: ConfigurationNode(object))

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

            Log.debug("Loading commandline arguments: \(argv)")

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

                    let rawValue = parseStringToObject ? self.deserializeFrom(value) : value
                    root[path] = ConfigurationNode(rawValue)
                }
            }
        case .environmentVariables:
            Log.debug("Loading environment variables: \(ProcessInfo.processInfo.environment)")

            for (path, value) in ProcessInfo.processInfo.environment {
                let index = path.replacingOccurrences(of: environmentVariablePathSeparator,
                                                      with: ConfigurationNode.separator)

                let rawValue = parseStringToObject ? self.deserializeFrom(value) : value
                root[index] = ConfigurationNode(rawValue)
            }
        }

        return self
    }

    /// Load configurations from a Data object
    /// - data: The Data object containing configurations.
    /// - parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e., `JSONDeserializer.name`; otherwise, parser will go through a list
    /// a deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(data: Data, deserializerName: String? = nil) -> ConfigurationManager {
        Log.debug("Loading data: \(data)")

        if let deserializerName = deserializerName,
            let deserializer = deserializers[deserializerName] {

            do {
                self.load(try deserializer.deserialize(data: data))
            }
            catch {
                Log.error("Unable to deserialize data using \"\(deserializerName)\" deserializer")
            }

            return self
        }
        else {
            for deserializer in deserializers.values {
                do {
                    return self.load(try deserializer.deserialize(data: data))
                }
                catch {
                    // try the next deserializer
                    continue
                }
            }

            Log.error("Unable to deserialize data using any known deserializer")

            return self
        }
    }

    /// Load configurations from a file on system.
    /// - parameter file: Path to file.
    /// - parameter relativeFrom: Optional. Defaults to the location of the executable.
    /// - parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize
    /// according to the given format, i.e., `JSONDeserializer.name`; otherwise, parser will
    /// go through a list a deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(file: String,
                     relativeFrom: BasePath = .executable,
                     deserializerName: String? = nil) -> ConfigurationManager {
        // get NSString representation to access some path APIs like `isAbsolutePath`
        // and `expandingTildeInPath`
        let fn = NSString(string: file)
        let pathURL: URL

        #if os(Linux) && !swift(>=3.1)
            let isAbsolutePath = fn.absolutePath
        #else
            let isAbsolutePath = fn.isAbsolutePath
        #endif

        if isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            pathURL = URL(fileURLWithPath: relativeFrom.path).appendingPathComponent(file).standardized
        }

        Log.verbose("Loading file: \(pathURL)")

        return self.load(url: pathURL, deserializerName: deserializerName)
    }

    /// Load configurations from a remote location.
    /// - parameter url: The URL pointing to a configuration resource.
    /// - parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e., `JSONDeserializer.name`; otherwise, parser will go through a list
    /// a deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(url: URL, deserializerName: String? = nil) -> ConfigurationManager {
        Log.verbose("Loading URL: \(url)")

        do {
            try self.load(data: Data(contentsOf: url), deserializerName: deserializerName)
        }
        catch {
            Log.error("Unable to load data from URL \(url)")
        }

        return self
    }

    /// Add a deserializer to the list.
    /// - paramter deserializer: The deserializer to be added.
    @discardableResult
    public func use(_ deserializer: Deserializer) -> ConfigurationManager {
        deserializers[deserializer.name] = deserializer

        return self
    }

    /// Get all configurations that have been merged in the manager as a raw object.
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

            root[path] = ConfigurationNode(rawValue)
        }
    }

    /// Deserialize a string into an object (i.e., a JSON string into a dictionary)
    /// - parameter str: The string to be deserialized.
    private func deserializeFrom(_ str: String) -> Any {
        if let data = str.data(using: .utf8) {
            for deserializer in deserializers.values {
                do {
                    return try deserializer.deserialize(data: data)
                }
                catch {
                    // try the next deserializer
                    continue
                }
            }
        }
        
        // str cannot be deserialized; return it as it is
        return str
    }
}

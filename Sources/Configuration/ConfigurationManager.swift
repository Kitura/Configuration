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
    // URLSession.shared isn't supported on Linux yet
    private let session = URLSession(configuration: URLSessionConfiguration.default)

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

    /// Base paths for resolving relative paths
    public enum BasePath {
        case executable
        case pwd
        case customPath(String)
    }

    private var deserializers: [String: Deserializer] = [
        JSONDeserializer.shared.name: JSONDeserializer.shared,
        PLISTDeserializer.shared.name: PLISTDeserializer.shared
    ]

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

                    root[path] = ConfigurationNode(value)
                }
            }
        case .environmentVariables:
            ProcessInfo.processInfo.environment.forEach {
                let index = $0.replacingOccurrences(of: environmentVariablePathSeparator,
                                                    with: ConfigurationNode.separator)

                root[index] = ConfigurationNode($1)
            }
        }

        return self
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
                     deserializerName: String? = nil) throws -> ConfigurationManager {
        // get NSString representation to access some path APIs like `isAbsolutePath`
        // and `expandingTildeInPath`
        let fn = NSString(string: file)
        let pathURL: URL

        #if os(Linux)
            let isAbsolutePath = fn.absolutePath
        #else
            let isAbsolutePath = fn.isAbsolutePath
        #endif

        if isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            var basePath: String

            switch relativeFrom {
            case .executable:
                basePath = executableFolderAbsolutePath
            case .pwd:
                basePath = pwd
            case .customPath(let path):
                basePath = path
            }

            pathURL = URL(fileURLWithPath: basePath).appendingPathComponent(file).standardized
        }

        return try self.load(url: pathURL, deserializerName: deserializerName)
    }

    /// Load configurations from a remote location.
    /// - parameter url: The URL pointing to a configuration resource.
    /// - parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e., `JSONDeserializer.name`; otherwise, parser will go through a list
    /// a deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(url: URL, deserializerName: String? = nil) throws -> ConfigurationManager {
        let data = try Data(contentsOf: url)

        if let deserializerName = deserializerName,
            let deserializer = deserializers[deserializerName] {
            self.load(try deserializer.deserialize(data: data))
        }
        else {
            for deserializer in deserializers.values {
                do {
                    self.load(try deserializer.deserialize(data: data))
                    break
                }
                catch {
                    // try the next deserializer
                    continue
                }
            }
            // TODO
            // maybe throw error here?
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
}

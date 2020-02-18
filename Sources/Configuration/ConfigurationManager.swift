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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import LoggerAPI
import FileKit

/// A one-stop shop to aggregate configuration properties from different sources, including
/// command-line arguments, environment variables, files, URLs and raw objects into a
/// single configuration store. Once the store has been populated configuration data
/// can be accessed and retrieved for an individual value, or multiple values, resources
/// can also be removed.
/// ### Usage Example ###
/// ```swift
/// import Configuration
///
/// let manager = ConfigurationManager()
/// manager.load(file: "config.json").load(.environmentVariables)
/// ```
/// To get configuration values after they have been loaded, use:
/// ```swift
/// manager["path:to:configuration:value"]
/// ```
/// The configuration store is represented as a tree, where the path elements in keys are delimited
/// by colons (`:`). The value returned is typed as `Any?`, therefore it's important to cast the value
/// to the type you want to use.
///
/// When aggregating configuration data from multiple sources, if the same configuration key
/// exists in multiple sources the one most recently loaded will override those loaded earlier.
/// In the example below the value for `foo` is now `baz` because `["foo": "baz"]` was more recently
/// loaded than `["foo": "bar"]`. The same behaviour applies to all other `load` functions.
///
/// ```swift
/// manager.load(["foo": "bar"]).load(["foo": "baz"])
/// ```
public class ConfigurationManager {
    // URLSession.shared isn't supported on Linux yet
    private let session = URLSession(configuration: URLSessionConfiguration.default)

    /// Internal tree representation of all config values
    private var root = ConfigurationNode.dictionary([:])

    /// List of known deserializers for parsing raw data (i.e. from file or HTTP requests)
    private var deserializers: [String: Deserializer] = [
        JSONDeserializer.shared.name: JSONDeserializer.shared,
        PLISTDeserializer.shared.name: PLISTDeserializer.shared
    ]

    /**
     Prefix used to denote a command line argument as a configuration path-value pair. Defaults to `--`
    
     For example: ```./myApp --path.to.configuration=value```
    
     Note: This can be set to your preferred prefix when instantiating `ConfigurationManager`.
     See: `init(commandLineArgumentKeyPrefix:commandLineArgumentPathSeparator:environmentVariablePathSeparator:parseStringToObject:)`
    */
    public var commandLineArgumentKeyPrefix: String

    /**
     Path separator to specify the components of a path that is passed in as a command line argument. Defaults to `.`
     
     For example: ```./myApp --path.to.configuration=value```
     
     Note: This can be set according to your preferences when instantiating `ConfigurationManager`.
     See: `init(commandLineArgumentKeyPrefix:commandLineArgumentPathSeparator:environmentVariablePathSeparator:parseStringToObject:)`
     */
    public var commandLineArgumentPathSeparator: String

    /**
     Path separator to specify the components of a path that is passed in as an environment variable. Defaults to `__`
     
     For example: ```PATH__TO__CONFIGURATION=value```
     
     Note: This can be set according to your preferences when instantiating `ConfigurationManager`.
     See: `init(commandLineArgumentKeyPrefix:commandLineArgumentPathSeparator:environmentVariablePathSeparator:parseStringToObject:)`
    */
    public var environmentVariablePathSeparator: String

    /**
     Used to indicate if string values in command-line arguments and environment variables should be parsed to
     array or dictionary, if possible, using a known Deserializer. Defaults to `true`
     
     Note: This can be set according to your preferences when instantiating `ConfigurationManager`.
     See: `init(commandLineArgumentKeyPrefix:commandLineArgumentPathSeparator:environmentVariablePathSeparator:parseStringToObject:)`
    */
    public var parseStringToObject: Bool

    /// Enum to specify the configuration source. The supported options are to load configuration
    /// data from either command-line arguments or environment variables.
    public enum Source {
        /// Flag to load configurations from command-line arguments.
        case commandLineArguments
        
        /// Flag to load configurations from environment variables.
        case environmentVariables
    }

    /// Base paths for resolving relative paths.
    public enum BasePath {
        /// Relative to the directory containing the executable itself.
        ///
        /// For example, when executing your project from the command line `~/.build/release/myApp`.
        case executable

        /** Relative to the project directory. (This is the directory containing the `Package.swift` of the project, determined by traversing up the directory structure starting at the directory containing the executable).

          Note: Because `BasePath.project` depends on the existence of a `Package.swift` file somewhere
          in a parent folder of the executable, changing its location using `swift build --build-path` is not
          supported.
        */
        case project

        /** Relative to the present working directory (PWD).
        
          Note: When running in Xcode, PWD is set to the directory containing the `Package.swift` of the project.
        */
        case pwd

        /// Relative to a custom location passed in by `String`.
        case customPath(String)

        /// Get the absolute path, as denoted by self.
        public var path: String {
            switch self {
            case .executable:
                return FileKit.executableFolder
            case .pwd:
                return FileKit.workingDirectory
            case .project:
                return FileKit.projectFolder
            case .customPath(let path):
                return path
            }
        }
    }

    /// Create a customized instance of `ConfigurationManager`. Used to customize the default prefix,
    /// path separators and string parsing options.
    ///
    /// ### Usage Example ###
    /// ```swift
    /// let customConfigMgr = ConfigurationManager.init(commandLineArgumentKeyPrefix: "---",
    ///                                                 commandLineArgumentPathSeparator: "_",
    ///                                                 environmentVariablePathSeparator: "___",
    ///                                                 parseStringToObject: false)
    /// ```
    ///
    /// - Parameter commandLineArgumentKeyPrefix: Optional. Used to denote an argument
    /// as a configuration path-value pair. Defaults to `--`
    /// - Parameter commandLineArgumentPathSeparator: Optional. Used to separate the
    /// components of a path. Defaults to `.`
    /// - Parameter environmentVariablePathSeparator: Optional. Used to separate the
    /// components of a path. Defaults to `__`
    /// - Parameter parseStringToObject: Optional. Used to indicate if string values
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

    /// Load configurations from a raw object.
    /// ### Usage Example ###
    /// ```swift
    /// manager.load([
    ///     "hello": "world",
    ///     "foo": [
    ///         "bar": "baz"
    ///     ]
    /// ])
    /// ```
    /// - Parameter object: The configurations object.
    @discardableResult
    public func load(_ object: Any) -> ConfigurationManager {
        Log.debug("Loading object: \(object)")

        root.merge(overwrittenBy: ConfigurationNode(object))

        return self
    }

    /// Load configurations from command-line arguments or environment variables.
    /// For command line arguments, the configurations are parsed from arguments
    /// in this format: `<keyPrefix><path>=<value>`.
    ///
    /// ### Usage Example (for command-line arguments) ###
    /// ```swift
    /// manager.load(.commandLineArguments)
    /// ```
    /// To inject configurations via the command-line at runtime, set configuration
    /// values when launching the executable as follows:
    ///
    /// `./myApp --path.to.configuration=value`
    ///
    /// ### Usage Example (for environment variables) ###
    /// ```swift
    /// manager.load(.environmentVariables)
    /// ```
    /// Then, to use it in your application, set environment variables as follows:
    ///
    /// `PATH__TO__CONFIGURATION=value`
    /// - Parameter source: Enum denoting which source to load from.
    @discardableResult
    public func load(_ source: Source) -> ConfigurationManager {
        switch source {
        case .commandLineArguments:
            let argv = CommandLine.arguments

            Log.debug("Loading command-line arguments: \(argv)")

            // skip first since it's always the executable
            for index in 1..<argv.count {
                // check if arg starts with keyPrefix
                if let prefixRange = argv[index].range(of: commandLineArgumentKeyPrefix),
                    prefixRange.lowerBound == argv[index].startIndex,
                    let breakRange = argv[index].range(of: "=") {
                    #if os(Linux)
                        // https://bugs.swift.org/browse/SR-5727
                        let path = String(argv[index][prefixRange.upperBound..<breakRange.lowerBound])
                        .replacingOccurrences(of: commandLineArgumentPathSeparator,
                        with: ConfigurationNode.separator)
                    #else
                        let path = argv[index][prefixRange.upperBound..<breakRange.lowerBound]
                            .replacingOccurrences(of: commandLineArgumentPathSeparator,
                                                  with: ConfigurationNode.separator)
                    #endif

                    let value = String(argv[index][breakRange.upperBound...])

                    let rawValue = parseStringToObject ? self.deserializeFrom(value) : value
                    root[path] = ConfigurationNode(rawValue)
                }
            }
        case .environmentVariables:
            Log.debug("Loading environment variables: \(ProcessInfo.processInfo.environment)")

            for (path, value) in ProcessInfo.processInfo.environment {
                let index = path.replacingOccurrences(of: environmentVariablePathSeparator,
                                                      with: ConfigurationNode.separator)

                // Attempt to deserialize environment variables using the JSON deserializer
                // only. Resolves: https://github.com/IBM-Swift/Configuration/issues/55
                let rawValue = parseStringToObject ? self.deserializeFrom(value, deserializerName: JSONDeserializer.shared.name) : value
                root[index] = ConfigurationNode(rawValue)
            }
        }

        return self
    }

    /// Load configurations from a Data object.
    ///
    /// ### Usage Example ###
    /// ```swift
    /// let data = Data(...)
    /// manager.load(data: data)
    /// ```
    ///
    /// - Parameter data: The Data object containing configurations.
    /// - Parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e. `JSONDeserializer.shared.name`; otherwise, the parser will go through a list
    /// of deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(data: Data, deserializerName: String? = nil) -> ConfigurationManager {
        Log.debug("Loading data: \(data)")

        if let deserializerName = deserializerName,
            let deserializer = deserializers[deserializerName] {

            do {
                self.load(try deserializer.deserialize(data: data))
            }
            catch {
                Log.warning("Unable to deserialize data using \"\(deserializerName)\" deserializer")
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

            Log.warning("Unable to deserialize data using any known deserializer")

            return self
        }
    }

    /// Load configurations from a file.
    ///
    /// ### Usage Example ###
    /// ```swift
    /// manager.load(file: "/path/to/file")
    /// ```
    ///
    /// By default, the `file` argument is a path relative to the location of the executable (.build/debug/myApp).
    /// If `file` is an absolute path, then it will be treated as such. You can change the relative-from path using
    /// the optional `relativeFrom` parameter as follows:
    /// ```swift
    /// // Resolve path against the current working directory
    /// manager.load(file: "../path/to/file", relativeFrom: .pwd)
    ///
    /// // Resolve path against a custom path
    /// manager.load(file: "../path/to/file", relativeFrom: .customPath("/path/to/somewhere/on/file/system"))
    /// ```
    /// Note: The following `relativeFrom` options: `.executable` (default) and `.pwd`, will reference different file
    /// system locations if the application is run from inside Xcode than if it is run from the command-line.
    /// You can set a compiler flag, i.e. `-DXCODE`, in your `.xcodeproj` and use the flag to change your
    /// configuration file loading logic.
    ///
    /// Note: `BasePath.project` depends on the existence of a `Package.swift` file somewhere in a
    /// parent folder of the executable, therefore, changing its location using `swift build --build-path`
    /// is not supported.
    ///
    /// - Parameter file: Path to file.
    /// - Parameter relativeFrom: Optional. Defaults to the location of the executable.
    /// - Parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize
    /// according to the given format, i.e. `JSONDeserializer.shared.name`; otherwise, the parser will
    /// go through a list of deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(file: String,
                     relativeFrom: BasePath = .executable,
                     deserializerName: String? = nil) -> ConfigurationManager {
        // get NSString representation to access some path APIs like `isAbsolutePath`
        // and `expandingTildeInPath`
        let fn = NSString(string: file)
        let pathURL: URL
        let isAbsolutePath = fn.isAbsolutePath

        if isAbsolutePath {
            pathURL = URL(fileURLWithPath: fn.expandingTildeInPath)
        }
        else {
            pathURL = URL(fileURLWithPath: relativeFrom.path).appendingPathComponent(file).standardized
        }

        return self.load(url: pathURL, deserializerName: deserializerName)
    }

    /// Load configurations from a URL location.
    ///
    /// ### Usage Example ###
    /// ```swift
    /// let url = URL(...)
    /// manager.load(url: url)
    /// ```
    /// Note: The `URL` MUST include a scheme, i.e. `file://`, `http://`, etc.
    ///
    /// - Parameter url: The URL pointing to a configuration resource.
    /// - Parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e. `JSONDeserializer.shared.name`; otherwise, the parser will go through a list
    /// of deserializers and attempt to deserialize using each one.
    @discardableResult
    public func load(url: URL, deserializerName: String? = nil) -> ConfigurationManager {
        Log.verbose("Loading URL: \(url.standardized.path)")

        do {
            try self.load(data: Data(contentsOf: url), deserializerName: deserializerName)
        }
        catch {
            Log.warning("Unable to load data from URL \(url.standardized.path)")
        }

        return self
    }

    /// Add a deserializer to the list of deserializers that can be used to parse raw data.
    ///
    /// - Parameter deserializer: The deserializer to be added.
    @discardableResult
    public func use(_ deserializer: Deserializer) -> ConfigurationManager {
        deserializers[deserializer.name] = deserializer

        return self
    }

    /// Get all configurations that have been merged into the `ConfigurationManager` as a raw object.
    public func getConfigs() -> Any {
        return root.rawValue
    }

    /// Access configurations by path.
    ///
    /// - Parameter path: The path to a configuration value.
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

    /// Deserialize a string into an object (i.e. a JSON string into a dictionary).
    ///
    /// - Parameter str: The string to be deserialized.
    /// - Parameter deserializerName: Optional. Designated deserializer for the configuration
    /// resource. Defaults to `nil`. Pass a value to force the parser to deserialize according to
    /// the given format, i.e., `JSONDeserializer.shared.name`; otherwise, parser will go through a list
    /// a deserializers and attempt to deserialize using each one.
    private func deserializeFrom(_ str: String, deserializerName: String? = nil) -> Any {
        guard let data = str.data(using: .utf8) else {
            return str
        }
        if let deserializerName = deserializerName,
            let deserializer = deserializers[deserializerName] {
            do {
                return try deserializer.deserialize(data: data)
            }
            catch {
                // str cannot be deserialized; return it as it is
                return str
            }
        }
        else {
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

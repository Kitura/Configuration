<p align="center">
    <a href="http://kitura.io/">
        <img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>


<p align="center">
    <a href="https://ibm-swift.github.io/Configuration/index.html">
    <img src="https://img.shields.io/badge/apidoc-Configuration-1FBCE4.svg?style=flat" alt="APIDoc">
    </a>
    <a href="https://travis-ci.org/IBM-Swift/Configuration">
    <img src="https://travis-ci.org/IBM-Swift/Configuration.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# Configuration

`Configuration` is a Swift package for managing application configurations. Using `Configuration`, an application can easily load and merge configuration data from multiple sources and access them from one central configuration store.

`Configuration` supports configuration keys as paths. That is, a key is a qualified path selector written in the `[parent]<separator>[child]` syntax. This allows applications to retrieve configuration objects at any level of specificity.

## Version
The latest release of `Configuration` (v3.x.x) runs on Swift 4.0 and newer, on both macOS and Ubuntu Linux.


## Usage

### Add dependencies

Add `Configuration` to the dependencies within your application's `Package.swift` file. Substitute `"x.x.x"` with the latest `Configuration` [release](https://github.com/IBM-Swift/Configuration/releases).

```swift
.package(url: "https://github.com/IBM-Swift/Configuration.git", from: "x.x.x")
```
Add `Configuration` to your target's dependencies:

```Swift
.target(name: "example", dependencies: ["Configuration"]),
```

### Initialize Configuration

The core of the `Configuration` package is the `ConfigurationManager` class. To manage your application's configurations, first create an instance of the `ConfigurationManager` class.

```swift
import Configuration

let manager = ConfigurationManager()
```

Using the `ConfigurationManager` instance, you can then load and retrieve configurations:

```swift
manager.load(file: "config.json").load(.environmentVariables)
let value = manager["path:to:configuration:value"]
```

## Loading Configuration Data

`Configuration` has many methods to load configuration data.

**NOTE:** In all cases, configuration key paths are case sensitive.

### From a Raw `Any` Object

```swift
manager.load([
    "hello": "world",
    "foo": [
        "bar": "baz"
    ]
])
```

### From Command-line Arguments

```swift
manager.load(.commandLineArguments)
```

To inject configurations via the command-line at runtime, set configuration values when launching the executable, like so:

```
./myApp --path.to.configuration=value
```

You can set your preferred argument prefix (default: `--`) and path separator (default: `.`) strings when instantiating `ConfigurationManager`.

### From Environment Variables

```swift
manager.load(.environmentVariables)
```

Then, to use it in your application, set environment variables like so:

```
PATH__TO__CONFIGURATION=value
```

You can set your preferred path separator (default: `__`) string when instantiating `ConfigurationManager`.

### From a `Data` Object

```swift
let data = Data(...)
manager.load(data: data)
```

### From a File

```swift
manager.load(file: "/path/to/file")
```

By default, the `file` argument is a path relative from the location of the executable (i.e., `.build/debug/myApp`); if `file` is an absolute path, then it will be treated as such. You can change the relative-from path using the optional `relativeFrom` parameter, like so:

```swift
// Resolve path against PWD
manager.load(file: "../path/to/file", relativeFrom: .pwd)

// or

// Resolve path against a custom path
manager.load(file: "../path/to/file", relativeFrom: .customPath("/path/to/somewhere/on/file/system"))
```

**NOTE:** The following `relativeFrom` options, `.executable` (default) and `.pwd`, will reference different file system locations if the application is run from inside Xcode than if it is run from the command-line. You can set a compiler flag, i.e. `-DXCODE`, in your `xcodeproj` and use the flag to change your configuration file loading logic.

**NOTE:** Because `BasePath.project` depends on the existence of a `Package.swift` file somewhere in a parent folder of the executable, changing its location using `swift build --build-path` is not supported.

### From a `URL`

```swift
let url = URL(...)
manager.load(url: url)
```

**NOTE:** The `URL` MUST include a scheme, i.e., `file://`, `http://`, etc.

### From Multiple Sources

You can chain these methods to load configuration data from multiple sources all at once. If the same configuration key exists in the multiple sources, the one most recently loaded will override the ones loaded earlier. In this simple example,

```swift
manager.load(["foo": "bar"]).load(["foo": "baz"])
```

the value for `foo` is now `baz` because `["foo": "baz"]` was more recently loaded than `["foo": "bar"]`. The same behavior applies to all other `load` functions.

**NOTE:** Currently, `Configuration` only supports JSON and PLIST formats for resources loaded from `Data`, file, or `URL`. You can write a [custom deserializer](https://ibm-swift.github.io/Configuration/Protocols/Deserializer.html) to parse additional formats.

## Accessing Configuration Data

To get individual configuration values after they have been loaded, use:

```swift
manager["path:to:configuration"]
```

The configuration store is represented as a tree, where the path elements in keys are delimited by colons (`:`). For instance, the key `VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host` would traverse into `VCAP_SERVICES`, `cloudantNoSQLDB`, array index 0, `credentials`, and then `host` to grab the value. Here is a JSON example of the structure:

```json
{
    "VCAP_SERVICES": {
        "cloudantNoSQLDB": [
            {
                "credentials": {
                    "host": <value-goes-here>
                }
            }
        ]
    }
}
```

The value returned is typed as `Any?`. Therefore, it's important to cast the value to the type you want to use. For instance:

```swift
let stringValue = manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host"] as? String
```

You can also retrieve configuration objects via partial paths; for example, if you use `manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials"]`, the result is a dictionary of the key-values in `credentials`.

To get all configuration values in the configuration store, use:

```swift
manager.getConfigs()
```

The return value is a raw representation of all configuration values currently in the configuration store.

## Acknowledgements
`Configuration` was inspired by [`nconf`](https://github.com/indexzero/nconf), a popular NodeJS hierarchical configuration manager.

## API Documentation
For more information visit our [API reference](https://ibm-swift.github.io/Configuration/index.html).

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](https://github.com/IBM-Swift/Configuration/blob/master/LICENSE).

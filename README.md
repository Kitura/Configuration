# Configuration

[![Build Status - Master](https://api.travis-ci.org/IBM-Swift/Configuration.svg?branch=master)](https://travis-ci.org/IBM-Swift/Configuration)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)
[![codecov](https://codecov.io/gh/IBM-Swift/Configuration/branch/master/graph/badge.svg)](https://codecov.io/gh/IBM-Swift/Configuration)

## Summary
`Configuration` is a Swift package for managing application configurations. Using `Configuration`, an application can easily load and merge configuration data from multiple sources and access them from one central configuration store.

`Configuration` supports configuration keys as paths. That is, a key is a qualified path selector written in the `[parent]<separator>[child]` syntax. This allows applications to retrieve configuration objects at any level of specificity.

## Version Info
`Configuration` runs on Swift 3, on both macOS and Ubuntu Linux.

## API Documentations
Full API documentations for `Configuration` can be found [here](https://ibm-swift.github.io/Configuration/index.html).

## Usage

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

## Loading configuration data

`Configuration` has many methods to load configuration data. 

**NOTE:** In all cases, configuration key paths are case sensitive.

### From a raw object:

```swift
manager.load([
    "hello": "world",
    "foo": [
        "bar": "baz"
    ]
])
```

### From command line arguments:

```swift
manager.load(.commandLineArguments)
```

To inject configurations via the commandline at runtime, set configuration values when launching the executable, like so:
    
```
./myApp --path.to.configuration=value
```

You can set your preferred argument prefix (`--`) and path separator (`.`) strings when instantiating `ConfigurationManager`.

### From environment variables:

```swift
manager.load(.environmentVariables)
```

Then, to use it in your application, set environment variables like so:

```
PATH__TO__CONFIGURATION=value
```

You can set your preferred path separator (default `__`) string when instantiating 'ConfigurationManager`.

### From a Data object:

```swift
let data = Data(...)
manager.load(data: data)
```

### From a file:

```swift
manager.load(file: "/path/to/file")
```

By default, the `file` argument is a path relative from the location of the executable (i.e., `.build/debug/myApp`); if `file` is an absolute path, then it will be treated as such. You can change the relative-from path using the optional `relativeFrom` parameter, like so:

```swift
manager.load(file: "../path/to/file", relativeFrom: .pwd)

// or

manager.load(file: "../path/to/file", relativeFrom: .customPath("/path/to/somewhere/on/file/system"))
```

### From a resource URL:
    
```swift
manager.load(url: myURL)
```

**NOTE:** The URL MUST include a scheme, i.e., `file://`, `http://`, etc.

### From multiple sources:

You can chain these methods to load configuration data from multiple sources all at once. If the same configuration key exists in the multiple sources, the one most recently loaded will override the ones loaded earlier. In this simple example,

```swift
manager.load(["foo": "bar"]).load(["foo": "baz"])
```

the value for `foo` is now `baz` because `["foo": "baz"]` was more recently loaded than `["foo": "bar"]`. The same behavior applies to all other `load` functions.

**NOTE:** Currently, `Configuration` only supports JSON and PLIST formats for resources loaded from data, file, or URL. You can write a custom deserializer to parse additional formats.

## Accessing configuration data

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

The value is returned as an instance of `Any`. Therefore, it's important to cast the value to the datatype you want to use. For instance:

```swift
let stringValue = manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host"] as? String
```

You can also retrieve configuration objects via partial paths; for example, if you use `manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials"]`, the result is a dictionary of the key-values in `credentials`.

To get all configuration values in the configuration store, use

```swift
manager.getConfigs()
```

The return value is raw representation of all configuration values currently in the configuration store.

## Acknowledgements
`Configuration` was inspired by [`nconf`](https://github.com/indexzero/nconf), a popular NodeJS hierarchical configuration manager.

## License
Apache 2.0

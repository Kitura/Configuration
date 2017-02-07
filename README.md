# Configuration

[![Build Status - Master](https://api.travis-ci.org/IBM-Swift/Configuration.svg?branch=master)](https://travis-ci.org/IBM-Swift/Configuration)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

## Summary
`Configuration` is a Swift package for managing application configurations. Using `Configuration`, an application can easily load and merge configuration data from multiple sources and access them from one central configuration store.

`Configuration` parses configuration keys as paths; that is, the configuration `<key, value>` map itself is a tree, much like JSON data.

## Version Info
`Configuration` runs on Swift 3, on both macOS and Ubuntu Linux.

## Usage

The core of the `Configuration` package is the `ConfigurationManager` class. To manage your application's configurations, first get an instance of the `ConfigurationManager` class.

```swift
import Configuration

let manager = ConfigurationManager()
```

Using the `ConfigurationManager` instance, you can then load and retrieve configurations:

```swift
do {
    try manager.load(file: "config.json")
               .load(.environmentVariables)
} catch { 
	
}
			  
let hostname = manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host"]
```

## Loading configuration data

`Configuration` has many methods to load configuration data.  If there are mulitple 

**NOTE:** In all cases, configuration key paths are case sensitive.

### From a raw object:

```swift
manager.load(myObject)
```

### From command line arguments:

```swift
manager.load(.commandLineArguments)
```

Then, to use it in your executable, set configuration values when launching the executable from commandline, like so:
    
```
./myApp --app.host=localhost:8090
```

You can set your preferred argument prefix (`--`) and path separator (`.`) strings when instantiating `ConfigurationManager`.

### From environment variables:

```swift
manager.load(.environmentVariables)
```

Then, to use it in your application, set environment variables like so:

```
app__host=localhost:8090
```

You can set your preferred path separator (`__`) string when instantiating 'ConfigurationManager`.

### From a JSON file:

```swift
try manager.load(file: "config.json")
```

By default, the `file` argument is a path relative from the location of the executable (i.e., `.build/debug/myapplication`). You can change the relative-from path using the optional `relativeFrom` parameter, like so:

```swift
try manager.load(file: "config.json", relativeFrom: .pwd)
```

### From a resource URL:
    
```swift
try manager.load(url: myURL)
```

**NOTE:** The URL MUST include a scheme, i.e., `file://` or `http://`


You can chain these methods to load configuration data from multiple sources all at once. If the same configuration key path exists in the multiple sources, the one most recently loaded will override the ones loaded earlier. In this example,

```swift
manager.load(myObject)
       .load(file: "config.json")
       .load(.commandLineArguments)
```

values in `myObject` could be overwritten by `config.json`'s values, and `config.json`'s values could be overwritten by the commandline arguments.

## Accessing configuration data

To get individual configuration values after they have been loaded, use:

```swift
manager["key-value-goes-here"]
```

The key values are represented as a tree, where they are delimited by colons (`:`). For instance, `VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host` would traverse into `VCAP_SERVICES`, `cloudantNoSQLDB`, array index 0, `credentials`, and then `host` to grab the value. The value is returned as an `Any`. Therefore, it's important to cast the value to the datatype you want to use. For instance:

```swift
let stringValue = manager["key-value-goes-here") as? String
```

You can also retrieve via partial paths, for example, if you use `manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials"]`, the result is a dictionary of the key-values in `credentials`.

You can also get all configuration values in the configuration store using

```swift
manager.getConfigs()
```

The return value is raw representation of all the merged configuration values currently in the configuration store.

## Acknowledgements
`Configuration` was inspired by [`nconf`](https://github.com/indexzero/nconf), a popular NodeJS hierarchical configuration manager.

## License
Apache 2.0

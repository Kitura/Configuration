# SwiftConfiguration

A hierarchical configuration loader for Swift.

## Getting Started

```swift
import SwiftConfiguration

let manager = ConfigurationManager()

do {
    try manager.load(file: "config.json")
               .load(.EnvironmentVariables)
} catch { 
	
}
			  
let hostname = manager["VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host"]
```

## Loading configuration data

SwiftConfiguration has many methods to load configuration data:

1. From environment variables:

    ```swift
    manager.load(.EnvironmentVariables)
    ```

2. From a JSON file:

    ```swift
    manager.load(file: "config.json")
    ```

3. From command line arguments:

    ```swift
    manager.load(.CommandLineArguments)
    ```

    Then, to use it in your executable, do:
    
    ```
    ./myApp --host=localhost:8090
    ```

4. From a raw object:

    ```swift
    manager.load(myObject)
    ```

5. From a remote location over HTTP:
    
    ```swift
    manager.load(url: myURL)
    ```
    
    **NOTE:** The URL MUST include a scheme, i.e., `file://` or `http://`

You can chain these methods so that configuration data can be obtained from multiple sources. Each subsequent method can possible overwrite the values loaded earlier. For instance:

```swift
manager.load(myObject)
       .load(file: "config.json")
       .load(.CommandLineArguments)

```

Values of the dictionary could be overwritten by the file's values, and the file's values could be overwritten with the command line arguments.

## Getting the configuration data

To get the values after they have been loaded, use:

```swift
manager["key-value-goes-here"]
```

The key values are represented as a tree, where they are delimited by colons (:). For instance, `VCAP_SERVICES:cloudantNoSQLDB:0:credentials:host` would traverse into the VCAP_SERVICES, cloudantNoSQLDB, index 0, credentials, and then host to grab the value. The value is returned as an `Any`. Therefore, it's important to cast the value to the datatype you want to use. For instance:

```swift
let stringValue = manager["key-value-goes-here") as? String
```


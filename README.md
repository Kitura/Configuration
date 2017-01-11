# SwiftConfiguration

A hierarchical configuration loader for Swift.

## Getting Started

```swift
import SwiftConfiguration

let manager = ConfigurationManager()

do {
    try manager.loadFile("config.json")
               .loadEnvironmentVariables()
} catch { 
	
}
			  
let hostname = manager.getValue(for: "VCAP_SERVICES:cloudantNoSQLDB:credentials:host")
```

## Loading configuration data

SwiftConfiguration has many methods to load configuration data:

1. From environment variables:

    ```swift
    manager.loadEnvironmentVariables()
    ```

2. From a JSON file:

    ```swift
    manager.loadFile("config.json")
    ```

3. From command line arguments:

    ```swift
    manager.loadCommandLineArguments()
    ```

    Then, to use it in your executable, do:
    
    ```
    ./myApp --host=localhost:8090
    ```

4. From a raw dictionary:

    ```swift
    manager.loadDictionary(myDictionary)
    ```

5. From a remote location over HTTP:
    
    ```swift
    manager.loadRemoteResource("http://example.com/config")
    ```
    
    **NOTE:** You MUST include the protocol scheme, i.e., `http://`, in the URL string

You can chain these methods so that configuration data can be obtained from multiple sources. Each subsequent method can possible overwrite the values loaded earlier. For instance:

```swift
manager.loadDictionary(myDictionary)
       .loadFile("config.json")
       .loadCommandLineArguments()

```

Values of the dictionary could be overwritten by the file's values, and the file's values could be overwritten with the command line arguments.

## Getting the configuration data

To get the values after they have been loaded, use:

```swift
manager.getValue(for: "key-value-goes-here")
```

The key values are represented as a tree, where they are delimited by colons (:). For instance, `VCAP_SERVICES:cloudantNoSQLDB:credentials:host` would traverse into the VCAP_SERVICES, cloudantNoSQLDB, credentials, and then host to grab the value. The value is returned as an `Any?`. Therefore, it's important to cast the value to the datatype you want to use. For instance:

```swift
let stringValue = manager.getValue(for: "key-value-goes-here") as? String
```


import Foundation
import Configuration

let executableURL = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
let executableFolder = executableURL.appendingPathComponent("..").standardized.path
var exitCode: Int32 = 0

var manager = ConfigurationManager()
manager.load(file: "TestResources/test.json", relativeFrom: .project)
if manager["OAuth:configuration:state"] as? Bool == true {
    print(".project: PASS")
} else {
    print(".project: FAIL")
    exitCode = 1
}

manager = ConfigurationManager()
manager.load(file: "../../TestResources/test.json", relativeFrom: .executable)
if manager["OAuth:configuration:state"] as? Bool == true {
    print(".executable: PASS")
} else {
    print(".executable: FAIL")
    exitCode = 1
}

manager = ConfigurationManager()
manager.load(file: "../../../TestResources/test.json", relativeFrom: .customPath(executableFolder + "/dummy"))
if manager["OAuth:configuration:state"] as? Bool == true {
    print(".customPath: PASS")
} else {
    print(".customPath: FAIL")
    exitCode = 1
}

manager = ConfigurationManager()
if FileManager().changeCurrentDirectoryPath(executableFolder + "/..") {
manager.load(file: "../TestResources/test.json", relativeFrom: .pwd)
    if manager["OAuth:configuration:state"] as? Bool == true {
        print(".pwd: PASS")
    } else {
        print(".pwd: FAIL")
        exitCode = 1
    }
} else {
    print(".pwd: FAIL (working directory)")
    exitCode = 1
}

exit(exitCode)

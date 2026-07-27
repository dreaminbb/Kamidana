import Foundation
import IOKit

let matching = IOServiceMatching("AppleARMIODevice")
var iterator: io_iterator_t = 0
if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
    var object: io_object_t = IOIteratorNext(iterator)
    while object != 0 {
        if let name = IORegistryEntryGetName(object, nil) {
           // print(String(cString: name)) // Too many, omit
        }
        IOObjectRelease(object)
        object = IOIteratorNext(iterator)
    }
}

import Foundation
import Darwin

var ifaddr: UnsafeMutablePointer<ifaddrs>?
if getifaddrs(&ifaddr) == 0 {
    var ptr = ifaddr
    while ptr != nil {
        let interface = ptr!.pointee
        if let data = interface.ifa_data, interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
            let networkData = data.assumingMemoryBound(to: if_data.self).pointee
            print("Interface: \(String(cString: interface.ifa_name)) - In: \(networkData.ifi_ibytes), Out: \(networkData.ifi_obytes)")
        }
        ptr = ptr?.pointee.ifa_next
    }
    freeifaddrs(ifaddr)
}

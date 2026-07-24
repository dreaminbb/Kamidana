import XCTest
import os

@testable import Kamidana

final class KamidanaTests: XCTestCase {

    func testSystemFunctionOnly() {
        // let logger = Logger()

        let test_range = 10
        let sysinfo = systemInfo()

        for i in 0..<test_range {

            let _ = sysinfo.getCPUUsage()
            let procInfo = sysinfo.getProcessAndThreadCount()
            let current_memory_usage = sysinfo.getMemoryUsed()
            let current_disk_usage = sysinfo.getDiskSpace(.total)

            print("プロセス数: \(procInfo.processes)")
            print("スレッド数: \(procInfo.threads)")

            print("Memory : \(current_memory_usage ?? 0)")
            print("Disk : \(current_disk_usage)")

            sleep(1)

        }
    }
}

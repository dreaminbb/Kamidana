import XCTest
import os

@testable import Kamidana

final class KamidanaTests: XCTestCase {

    // func testSystemFunctionOnly() {
    //     // let logger = Logger()
    //
    //     let test_range = 10
    //     let sysinfo = systemInfo()
    //
    //     for i in 0..<test_range {
    //
    //         let _ = sysinfo.getCPUUsage()
    //         let procInfo = sysinfo.getProcessAndThreadCount()
    //         let current_memory_usage = sysinfo.getMemoryUsed()
    //         let current_disk_usage = sysinfo.getDiskSpace(.total)
    //
    //         print("プロセス数: \(procInfo.processes)")
    //         print("スレッド数: \(procInfo.threads)")
    //
    //         print("Memory : \(current_memory_usage ?? 0)")
    //         print("Disk : \(current_disk_usage)")
    //
    //         sleep(1)
    //
    //     }
    // }
    //
    // func testGetCoreUsage() {
    //     let sysinfoIns = systemInfo()
    //     var allCoreUsage: [[Float]] = []
    //     for i in 0..<10 {
    //         let data = sysinfoIns.getCPUUsage()
    //         allCoreUsage.append(data.perCore)
    //         print("\(i)秒目: \(allCoreUsage)")
    //         sleep(1)
    //     }
    // }

    // func testGetCPUClock() {
    //
    //     let sysinfoIns = systemInfo()
    //     let cpu_clock = sysinfoIns.getCPUClock()
    //     print("周波数：\(cpu_clock)")
    //
    // }

    func testsystemMatrix() {

        let sysinfoIns = systemInfo()
        let _ = sysinfoIns.runSystemMatrixCommand()
    }
}

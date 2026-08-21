import XCTest
@testable import KamidanaApp

final class TopProcessTests: XCTestCase {
    func testTopProcesses() {
        let args = SystemMatrixArgs(cpu: true, memory: true, disk: true, internet: false, power: false, gpu: false, thermal: false, battery: false)
        let matrix = SystemMatrix(args: args)
        
        let expectation1 = XCTestExpectation(description: "Fetch 1")
        matrix.fetchData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation1.fulfill()
        }
        wait(for: [expectation1], timeout: 2.0)
        
        let expectation2 = XCTestExpectation(description: "Fetch 2")
        matrix.fetchData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation2.fulfill()
        }
        wait(for: [expectation2], timeout: 2.0)
        
        let data = matrix.data
        
        XCTAssertNotNil(data.topCPU)
        XCTAssertNotNil(data.topMemory)
        XCTAssertNotNil(data.topDisk)
        XCTAssertNotNil(data.diskIOUsage)
        
        if let topCpu = data.topCPU {
            print("--- Top CPU Processes ---")
            for p in topCpu {
                print("\(p.name) (PID \(p.id)): \(String(format: "%.1f", p.cpuUsage))% (Icon: \(p.icon != nil ? "YES" : "NO"))")
            }
        }
        
        if let topMem = data.topMemory {
            print("--- Top Memory Processes ---")
            for p in topMem {
                print("\(p.name) (PID \(p.id)): \(p.memoryBytes / 1024 / 1024) MB (Icon: \(p.icon != nil ? "YES" : "NO"))")
            }
        }
        
        if let topDisk = data.topDisk {
            print("--- Top Disk Processes ---")
            for p in topDisk {
                print("\(p.name) (PID \(p.id)): Read \(p.diskReadBytesPerSec) B/s, Write \(p.diskWriteBytesPerSec) B/s")
            }
        }
        
        if let diskIO = data.diskIOUsage {
            print("--- Global Disk I/O ---")
            print("Read: \(diskIO.readBytesPerSecond) B/s, Write: \(diskIO.writeBytesPerSecond) B/s")
        }
    }
}

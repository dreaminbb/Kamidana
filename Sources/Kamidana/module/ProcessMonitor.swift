import AppKit
import Darwin
import Foundation

public struct ProcessStat: Identifiable {
    public let id: Int32 // PID
    public let name: String
    public let path: String
    public var icon: NSImage?
    
    public var cpuUsage: Double // %
    public var memoryBytes: UInt64
    public var diskReadBytesPerSec: UInt64
    public var diskWriteBytesPerSec: UInt64
    
    fileprivate var lastCPUTime: UInt64
    fileprivate var lastDiskRead: UInt64
    fileprivate var lastDiskWrite: UInt64
    fileprivate var lastCheckTime: Date
}

public class ProcessMonitor {
    private var processes: [Int32: ProcessStat] = [:]
    
    public init() {}
    
    public func update() {
        var pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        let count = pidsSize / Int32(MemoryLayout<pid_t>.size)
        var pids = [pid_t](repeating: 0, count: Int(count))
        pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidsSize)
        
        let now = Date()
        var currentProcesses: [Int32: ProcessStat] = [:]
        
        for pid in pids {
            if pid == 0 { continue }
            
            var taskInfo = proc_taskinfo()
            let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            if size != Int32(MemoryLayout<proc_taskinfo>.size) { continue }
            
            let cpuTime = taskInfo.pti_total_user + taskInfo.pti_total_system
            let memory = taskInfo.pti_resident_size
            
            var rusage = rusage_info_v4()
            var diskRead: UInt64 = 0
            var diskWrite: UInt64 = 0
            
            let rusageResult = withUnsafeMutablePointer(to: &rusage) { ptr in
                ptr.withMemoryRebound(to: (rusage_info_t?).self, capacity: 1) { rusagePtr in
                    proc_pid_rusage(pid, Int32(RUSAGE_INFO_V4), rusagePtr)
                }
            }
            if rusageResult == 0 {
                diskRead = rusage.ri_diskio_bytesread
                diskWrite = rusage.ri_diskio_byteswritten
            }
            
            if var existing = processes[pid] {
                let timeDiff = now.timeIntervalSince(existing.lastCheckTime)
                if timeDiff > 0 {
                    let cpuDiff = cpuTime > existing.lastCPUTime ? cpuTime - existing.lastCPUTime : 0
                    let nsDiff = timeDiff * 1_000_000_000.0
                    existing.cpuUsage = (Double(cpuDiff) / nsDiff) * 100.0
                    
                    let readDiff = diskRead > existing.lastDiskRead ? diskRead - existing.lastDiskRead : 0
                    let writeDiff = diskWrite > existing.lastDiskWrite ? diskWrite - existing.lastDiskWrite : 0
                    existing.diskReadBytesPerSec = UInt64(Double(readDiff) / timeDiff)
                    existing.diskWriteBytesPerSec = UInt64(Double(writeDiff) / timeDiff)
                }
                existing.memoryBytes = memory
                existing.lastCPUTime = cpuTime
                existing.lastDiskRead = diskRead
                existing.lastDiskWrite = diskWrite
                existing.lastCheckTime = now
                currentProcesses[pid] = existing
            } else {
                var buffer = [Int8](repeating: 0, count: 4096)
                let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
                var path = ""
                var name = "Unknown"
                if length > 0 {
                    path = String(cString: buffer)
                    name = URL(fileURLWithPath: path).lastPathComponent
                }
                
                if path.isEmpty { continue }
                
                let icon = NSWorkspace.shared.icon(forFile: path)
                
                let newStat = ProcessStat(
                    id: pid,
                    name: name,
                    path: path,
                    icon: icon,
                    cpuUsage: 0.0,
                    memoryBytes: memory,
                    diskReadBytesPerSec: 0,
                    diskWriteBytesPerSec: 0,
                    lastCPUTime: cpuTime,
                    lastDiskRead: diskRead,
                    lastDiskWrite: diskWrite,
                    lastCheckTime: now
                )
                currentProcesses[pid] = newStat
            }
        }
        
        self.processes = currentProcesses
    }
    
    public func getTopCPU(limit: Int = 5) -> [ProcessStat] {
        return Array(processes.values.sorted { $0.cpuUsage > $1.cpuUsage }.prefix(limit))
    }
    
    public func getTopMemory(limit: Int = 5) -> [ProcessStat] {
        return Array(processes.values.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(limit))
    }
    
    public func getTopDisk(limit: Int = 5) -> [ProcessStat] {
        return Array(processes.values.sorted { ($0.diskReadBytesPerSec + $0.diskWriteBytesPerSec) > ($1.diskReadBytesPerSec + $1.diskWriteBytesPerSec) }.prefix(limit))
    }
}

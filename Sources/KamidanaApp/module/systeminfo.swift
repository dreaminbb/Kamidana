import Combine
import Darwin
import Foundation
import IOKit
import IOKit.ps

// Display items configurable by the user (can be parsed from JSON, etc.)
struct SystemMatrixArgs: Codable {
    var cpu: Bool = false
    var memory: Bool = false
    var disk: Bool = false
    var internet: Bool = false
    var power: Bool = false
    var gpu: Bool = false
    var thermal: Bool = false  // Thermal / Fan settings
    var battery: Bool = false  // Battery settings
}

// Structure holding all fetched system matrix data
struct SystemMatrixData {
    var cpuUsage: CPUUsageInfo?
    var memoryMB: UInt64?
    var processCount: Int?
    var threadCount: Int?
    var diskSpace: String?
    var gpuUsage: GPUUsageInfo?
    var powerUsage: PowerUsageInfo?
    var internetUsage: NetworkUsageInfo?
    var thermalState: String?  // Mac thermal state
    var batteryUsage: BatteryUsageInfo?  // Battery usage info
    var topCPU: [ProcessStat]?  // Top processes (CPU)
    var topGPU: [GPUProcessStat]?  // Top processes (GPU)
    var topMemory: [ProcessStat]?  // Top processes (Memory)
    var topDisk: [ProcessStat]?  // Top processes (Disk)
    var diskIOUsage: DiskUsageInfo?  // Overall disk I/O usage
}

// Structure for network transfer speeds
struct NetworkUsageInfo {
    var uploadBytesPerSecond: UInt64
    var downloadBytesPerSecond: UInt64
}

// Structure for disk I/O speeds
struct DiskUsageInfo {
    var readBytesPerSecond: UInt64
    var writeBytesPerSecond: UInt64
}

// Structure for CPU usage rates
struct CPUUsageInfo {
    var total: Float
    var perCore: [Float]
}

// Structure for GPU information
struct GPUUsageInfo {
    var activeRatio: Float
}

struct WatInfo {
    var activeWatts: Float
    var amperage: Float
    var voltage: Float
    var isCharging: Bool
}

// Structure for battery information
struct BatteryUsageInfo {
    var isCharging: Bool
    var currentCapacity: Int64
    var timeToEmpty: Int64
    var timeToFull: Int64
    var wattInfo: WatInfo?
}

// Structure for power consumption info (for future extension)
struct PowerUsageInfo {
    var packageWatts: Float
}

enum DiskSpaceType {
    case total
    case free
    case used
}

// Main class to fetch and retain only necessary info based on args (configuration)
class SystemMatrix: ObservableObject {
    typealias MegaByte = UInt64
    static let topProcessLimit = 8

    // Data observed by the UI
    @Published var data = SystemMatrixData()

    // Configuration parameters
    var args: SystemMatrixArgs

    // Internal state
    private var timer: AnyCancellable?
    private var batteryTimer: AnyCancellable?
    private let fetchQueue = DispatchQueue(
        label: "com.shin.Kamidana.system-fetch",
        qos: .utility
    )

    // State for network calculation
    private var prevNetworkInput: UInt64 = 0
    private var prevNetworkOutput: UInt64 = 0
    private var isFirstNetworkFetch = true

    // State for disk I/O calculation
    private var prevDiskRead: UInt64 = 0
    private var prevDiskWrite: UInt64 = 0
    private var isFirstDiskFetch = true

    // State for CPU calculation
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorCount: mach_msg_type_number_t = 0
    private var previousCPUUsage = CPUUsageInfo(total: 0.0, perCore: [])

    // Manager for process monitoring
    private var processMonitor = ProcessMonitor()
    private var gpuProcessMonitor = GPUProcessMonitor()

    init(args: SystemMatrixArgs) {
        self.args = args
    }

    /// Start periodic monitoring
    func startMonitoring() {
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchData()
            }
        if args.battery {
            batteryTimer = Timer.publish(every: 5.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.fetchBatteryData()
                }
            fetchBatteryData()
        }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
        batteryTimer?.cancel()
        batteryTimer = nil
    }

    /// Fetch only the necessary data based on args configuration
    func fetchData() {
        // Execute asynchronously in the background
        fetchQueue.async { [weak self] in
            guard let self = self else { return }
            var newData = self.data  // Base on current data

            // Update process stats (for top CPU, Memory, Disk processes)
            self.processMonitor.update()

            if self.args.cpu {
                newData.cpuUsage = self.getCPUUsage()
                let procData = self.getProcessAndThreadCount()
                newData.processCount = procData.processes
                newData.threadCount = procData.threads
                newData.topCPU = self.processMonitor.getTopCPU(limit: Self.topProcessLimit)
            }
            if self.args.gpu {
                newData.gpuUsage = self.getGPUUsage()
                self.gpuProcessMonitor.update()
                newData.topGPU = self.gpuProcessMonitor.topProcesses(limit: Self.topProcessLimit)
            }
            if self.args.thermal {
                newData.thermalState = self.getThermalState()
            }
            if self.args.memory {
                newData.memoryMB = self.getMemoryUsed()
                newData.topMemory = self.processMonitor.getTopMemory(limit: Self.topProcessLimit)
            }
            if self.args.disk {
                newData.diskSpace = self.getDiskSpace(.used)
                newData.topDisk = self.processMonitor.getTopDisk(limit: Self.topProcessLimit)
                newData.diskIOUsage = self.getDiskIOUsage()
            }
            if self.args.internet {
                newData.internetUsage = self.getNetworkUsage()
            }
            // Reflect to UI on the main thread after fetching
            DispatchQueue.main.async {
                self.data = newData
                // DebugRichConsole.printSystemMatrix(newData)
            }
        }
    }

    private func fetchBatteryData() {
        guard args.battery else { return }
        fetchQueue.async { [weak self] in
            guard let self else { return }
            let batteryUsage = self.getBatteryUsageInfo()
            DispatchQueue.main.async {
                self.data.batteryUsage = batteryUsage
            }
        }
    }

    /// Fetch GPU usage via IOKit
    private func getGPUUsage() -> GPUUsageInfo? {
        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)

        guard result == kIOReturnSuccess else { return nil }

        var activeRatio: Float? = nil
        var object: io_object_t = IOIteratorNext(iterator)

        while object != 0 {
            if let properties = IORegistryEntryCreateCFProperty(
                object, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            {
                // Use "Device Utilization %" directly if present (standard approach across Intel/Apple Silicon)
                if let utilization = properties["Device Utilization %"] as? Int {
                    activeRatio = Float(utilization)
                    IOObjectRelease(object)
                    break
                }
            }
            IOObjectRelease(object)
            object = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        if let ratio = activeRatio {
            return GPUUsageInfo(activeRatio: ratio)
        }
        return nil
    }

    /// Fetch thermal state of the Mac
    private func getThermalState() -> String {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            return "Normal"  // Nominal - no thermal throttling
        case .fair:
            return "Warm"  // Fair - fans may spin up
        case .serious:
            return "Hot"  // Serious - risk of performance throttling
        case .critical:
            return "Critical"  // Critical - system emergency thermal state
        @unknown default:
            return "Unknown"
        }
    }

    /// Fetch system-wide CPU usage (%) and per-core usage
    private func getCPUUsage() -> CPUUsageInfo {
        var processorInfo: processor_info_array_t?
        var processorCount: mach_msg_type_number_t = 0
        var processorMsgCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &processorInfo,
            &processorMsgCount
        )

        guard result == KERN_SUCCESS, let info = processorInfo else { return previousCPUUsage }

        guard let prev = prevProcessorInfo else {
            prevProcessorInfo = info
            prevProcessorCount = processorCount
            previousCPUUsage.perCore = Array(repeating: 0.0, count: Int(processorCount))
            return previousCPUUsage
        }

        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        var totalNice: UInt32 = 0

        var currentCoreUsages: [Float] = []

        for i in 0..<Int(processorCount) {
            let index = Int(CPU_STATE_MAX) * i
            let u =
                UInt32(bitPattern: info[index + Int(CPU_STATE_USER)])
                &- UInt32(bitPattern: prev[index + Int(CPU_STATE_USER)])
            let s =
                UInt32(bitPattern: info[index + Int(CPU_STATE_SYSTEM)])
                &- UInt32(bitPattern: prev[index + Int(CPU_STATE_SYSTEM)])
            let i_tick =
                UInt32(bitPattern: info[index + Int(CPU_STATE_IDLE)])
                &- UInt32(bitPattern: prev[index + Int(CPU_STATE_IDLE)])
            let n =
                UInt32(bitPattern: info[index + Int(CPU_STATE_NICE)])
                &- UInt32(bitPattern: prev[index + Int(CPU_STATE_NICE)])

            let coreTotal = Double(u &+ s &+ i_tick &+ n)
            if coreTotal > 0.0 {
                let coreUsage = Double(u &+ s &+ n) / coreTotal
                currentCoreUsages.append(Float(coreUsage * 100.0))
            } else {
                currentCoreUsages.append(
                    previousCPUUsage.perCore.indices.contains(i) ? previousCPUUsage.perCore[i] : 0.0
                )
            }

            totalUser &+= u
            totalSystem &+= s
            totalIdle &+= i_tick
            totalNice &+= n
        }

        let totalDiff = Double(totalUser &+ totalSystem &+ totalIdle &+ totalNice)
        if totalDiff < 1.0 {
            let size = Int(processorMsgCount) * MemoryLayout<integer_t>.size
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(size))
            return previousCPUUsage
        }

        let usage = Double(totalUser &+ totalSystem &+ totalNice) / totalDiff

        let prevSize =
            Int(prevProcessorCount * UInt32(CPU_STATE_MAX)) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevSize))

        prevProcessorInfo = info
        prevProcessorCount = processorCount
        previousCPUUsage = CPUUsageInfo(total: Float(usage * 100.0), perCore: currentCoreUsages)

        return previousCPUUsage
    }

    /// Fetch network transfer speed (upload/download)
    private func getNetworkUsage() -> NetworkUsageInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }

        var currentInput: UInt64 = 0
        var currentOutput: UInt64 = 0

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)

            // Exclude loopback (lo0) and measure only physical network traffic
            if name.hasPrefix("lo") { continue }

            // AF_LINK data structure contains transferred and received byte counts
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    currentInput &+= UInt64(networkData.ifi_ibytes)
                    currentOutput &+= UInt64(networkData.ifi_obytes)
                }
            }
        }
        freeifaddrs(ifaddr)

        // Create baseline on first call and return 0
        if isFirstNetworkFetch {
            prevNetworkInput = currentInput
            prevNetworkOutput = currentOutput
            isFirstNetworkFetch = false
            return NetworkUsageInfo(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
        }

        // Calculate diff from previous interval (1 second ago)
        let diffInput = currentInput >= prevNetworkInput ? currentInput - prevNetworkInput : 0
        let diffOutput = currentOutput >= prevNetworkOutput ? currentOutput - prevNetworkOutput : 0

        prevNetworkInput = currentInput
        prevNetworkOutput = currentOutput

        return NetworkUsageInfo(uploadBytesPerSecond: diffOutput, downloadBytesPerSecond: diffInput)
    }

    /// Fetch disk I/O speeds (Read/Write)
    private func getDiskIOUsage() -> DiskUsageInfo? {
        let matchingDict = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0

        guard
            IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
                == kIOReturnSuccess
        else { return nil }

        var currentRead: UInt64 = 0
        var currentWrite: UInt64 = 0

        var object: io_object_t = IOIteratorNext(iterator)
        while object != 0 {
            if let props = IORegistryEntryCreateCFProperty(
                object, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
                as? [String: Any]
            {
                if let bytesRead = props["Bytes (Read)"] as? UInt64 { currentRead += bytesRead }
                if let bytesWrite = props["Bytes (Write)"] as? UInt64 { currentWrite += bytesWrite }
            }
            IOObjectRelease(object)
            object = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        if isFirstDiskFetch {
            prevDiskRead = currentRead
            prevDiskWrite = currentWrite
            isFirstDiskFetch = false
            return DiskUsageInfo(readBytesPerSecond: 0, writeBytesPerSecond: 0)
        }

        let diffRead = currentRead >= prevDiskRead ? currentRead - prevDiskRead : 0
        let diffWrite = currentWrite >= prevDiskWrite ? currentWrite - prevDiskWrite : 0

        prevDiskRead = currentRead
        prevDiskWrite = currentWrite

        return DiskUsageInfo(readBytesPerSecond: diffRead, writeBytesPerSecond: diffWrite)
    }

    private func getMemoryUsed() -> MegaByte? {
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStats = vm_statistics64()

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let wired = UInt64(vmStats.wire_count) * pageSize
            let active = UInt64(vmStats.active_count) * pageSize
            let compressed = UInt64(vmStats.compressor_page_count) * pageSize
            return (wired + active + compressed) / 1024 / 1024
        }
        return nil
    }

    private func getProcessAndThreadCount() -> (processes: Int, threads: Int) {
        var pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        let count = pidsSize / Int32(MemoryLayout<pid_t>.size)

        var pids = [pid_t](repeating: 0, count: Int(count))
        pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidsSize)

        var totalThreads = 0
        var totalProcesses = 0

        for pid in pids {
            if pid == 0 { continue }
            totalProcesses += 1

            var taskInfo = proc_taskinfo()
            let size = proc_pidinfo(
                pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            if size == Int32(MemoryLayout<proc_taskinfo>.size) {
                totalThreads += Int(taskInfo.pti_threadnum)
            }
        }
        return (totalProcesses, totalThreads)
    }

    private func getDiskSpace(_ type: DiskSpaceType) -> String {
        let byteUnitStringConverted: (Int64) -> String = { size in
            ByteCountFormatter.string(fromByteCount: size, countStyle: .binary)
        }

        guard
            let attributes = try? FileManager.default.attributesOfFileSystem(
                forPath: NSHomeDirectory()),
            let total = (attributes[.systemSize] as? NSNumber)?.int64Value,
            let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value
        else {
            return "0 MB"
        }

        switch type {
        case .total: return byteUnitStringConverted(total)
        case .free: return byteUnitStringConverted(free)
        case .used: return byteUnitStringConverted(total - free)
        }
    }

    public func powerInfoSnapShot() -> [String: Any]? {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
                as? [String: Any]
            {
                return desc
            }
        }
        return nil
    }

    // return value - = discharging
    // return value + = charging
    // used to determine isCharging
    public func getChargingPowerWat() -> WatInfo? {
        let matchingDict = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
            == kIOReturnSuccess
        {
            var _amperage: Float = 0.0
            var _voltage: Float = 0.0
            var _isCharging: Bool = false
            var _activeWatts: Float = 0.0

            var object: io_object_t = IOIteratorNext(iterator)
            while object != 0 {
                var props: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(object, &props, kCFAllocatorDefault, 0)
                    == kIOReturnSuccess
                {
                    if let d = props?.takeRetainedValue() as? [String: Any] {
                        _amperage = Float(d["Amperage"] as? Int ?? 0)
                        _voltage = Float(d["Voltage"] as? Int ?? 0)
                        _isCharging = (_amperage >= 0)  // Values >= 0 indicate charging / AC power
                        _activeWatts = Float(abs(_amperage) * _voltage) / 1_000_000.0
                    }
                }
                IOObjectRelease(object)
                object = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            return WatInfo(
                activeWatts: _activeWatts, amperage: _amperage, voltage: _voltage,
                isCharging: _isCharging)
        }
        return nil
    }

    public func getIsNowCharging() -> Bool {
        guard let desc = powerInfoSnapShot() else { return false }
        return (desc["Is Charging"] as? Bool) ?? false
    }

    public func currentBatteryCharged() -> Int64 {
        guard let desc = powerInfoSnapShot() else { return 0 }
        return (desc["Current Capacity"] as? Int64) ?? 0
    }

    public func batteryTimeLeft() -> Int64 {
        guard let desc = powerInfoSnapShot() else { return 0 }
        return (desc["Time to Empty"] as? Int64) ?? 0
    }

    public func chargingTimeLeft() -> Int64 {
        guard let desc = powerInfoSnapShot() else { return 0 }
        return (desc["Time to Full Charge"] as? Int64) ?? 0
    }

    private static func batteryInt64(_ value: Any?) -> Int64 {
        if let number = value as? NSNumber { return number.int64Value }
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        return 0
    }

    private static func batteryBool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }

    /// Fetch and return consolidated battery usage information
    private func getBatteryUsageInfo() -> BatteryUsageInfo {
        let snapshot = powerInfoSnapShot()
        return BatteryUsageInfo(
            isCharging: Self.batteryBool(snapshot?["Is Charging"]),
            currentCapacity: Self.batteryInt64(snapshot?["Current Capacity"]),
            timeToEmpty: Self.batteryInt64(snapshot?["Time to Empty"]),
            timeToFull: Self.batteryInt64(snapshot?["Time to Full Charge"]),
            wattInfo: getChargingPowerWat()
        )
    }

}

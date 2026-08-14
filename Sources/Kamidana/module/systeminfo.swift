import Combine
import Darwin
import Foundation
import IOKit
import IOKit.ps

// ユーザーが設定できる表示項目（JSON等から変換可能）
struct SystemMatrixArgs: Codable {
    var cpu: Bool = false
    var memory: Bool = false
    var disk: Bool = false
    var internet: Bool = false
    var power: Bool = false
    var gpu: Bool = false
    var thermal: Bool = false  // 追加：サーマル・ファン設定
    var battery: Bool = false  // 追加：バッテリー設定
}

// 取得したシステムデータを一括で保持する構造体
struct SystemMatrixData {
    var cpuUsage: CPUUsageInfo?
    var memoryMB: UInt64?
    var processCount: Int?
    var threadCount: Int?
    var diskSpace: String?
    var gpuUsage: GPUUsageInfo?
    var powerUsage: PowerUsageInfo?
    var internetUsage: NetworkUsageInfo?
    var thermalState: String?  // 追加：Macの温度状態
    var batteryUsage: BatteryUsageInfo? // 追加：バッテリー情報
    var topCPU: [ProcessStat]? // 追加：トッププロセス（CPU）
    var topMemory: [ProcessStat]? // 追加：トッププロセス（メモリ）
    var topDisk: [ProcessStat]? // 追加：トッププロセス（ディスク）
    var diskIOUsage: DiskUsageInfo? // 追加：ディスク全体のI/O
}

// 通信速度をまとめる構造体
struct NetworkUsageInfo {
    var uploadBytesPerSecond: UInt64
    var downloadBytesPerSecond: UInt64
}

// ディスクI/O速度をまとめる構造体
struct DiskUsageInfo {
    var readBytesPerSecond: UInt64
    var writeBytesPerSecond: UInt64
}

// CPUの使用率をまとめる構造体
struct CPUUsageInfo {
    var total: Float
    var perCore: [Float]
}

// GPU情報をまとめる構造体
struct GPUUsageInfo {
    var activeRatio: Float
}

struct WatInfo {
    var activeWatts: Float
    var amperage: Float
    var voltage: Float
    var isCharging: Bool
}

// バッテリー情報をまとめる構造体
struct BatteryUsageInfo {
    var isCharging: Bool
    var currentCapacity: Int64
    var timeToEmpty: Int64
    var timeToFull: Int64
    var wattInfo: WatInfo?
}

// 電力量をまとめる構造体（拡張用）
struct PowerUsageInfo {
    var packageWatts: Float
}

enum DiskSpaceType {
    case total
    case free
    case used
}

// args(設定)に基づいて必要な情報だけを取得・保持するメインクラス
class SystemMatrix: ObservableObject {
    typealias MegaByte = UInt64

    // UI側で監視するデータ
    @Published var data = SystemMatrixData()

    // 設定パラメータ
    var args: SystemMatrixArgs

    // 内部状態
    private var timer: AnyCancellable?

    // ネットワーク計算用の状態保存
    private var prevNetworkInput: UInt64 = 0
    private var prevNetworkOutput: UInt64 = 0
    private var isFirstNetworkFetch = true

    // ディスクI/O計算用の状態保存
    private var prevDiskRead: UInt64 = 0
    private var prevDiskWrite: UInt64 = 0
    private var isFirstDiskFetch = true

    // CPU計算用の状態保存
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorCount: mach_msg_type_number_t = 0
    private var previousCPUUsage = CPUUsageInfo(total: 0.0, perCore: [])
    
    // プロセス監視用のマネージャー
    private var processMonitor = ProcessMonitor()

    init(args: SystemMatrixArgs) {
        self.args = args
    }

    /// 定期モニタリングを開始する
    func startMonitoring() {
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchData()
            }
    }

    func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }

    /// 設定(args)に基づいて、必要なデータだけを取得する
    func fetchData() {
        // バックグラウンドで非同期に実行
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            var newData = self.data  // 現在のデータをベースにする
            
            // プロセス情報を更新（CPU, Mem, Diskのトッププロセスのため）
            self.processMonitor.update()

            if self.args.cpu {
                newData.cpuUsage = self.getCPUUsage()
                let procData = self.getProcessAndThreadCount()
                newData.processCount = procData.processes
                newData.threadCount = procData.threads
                newData.topCPU = self.processMonitor.getTopCPU(limit: 5)
            }
            if self.args.gpu {
                newData.gpuUsage = self.getGPUUsage()
            }
            if self.args.thermal {
                newData.thermalState = self.getThermalState()
            }
            if self.args.memory {
                newData.memoryMB = self.getMemoryUsed()
                newData.topMemory = self.processMonitor.getTopMemory(limit: 5)
            }
            if self.args.disk {
                newData.diskSpace = self.getDiskSpace(.used)
                newData.topDisk = self.processMonitor.getTopDisk(limit: 5)
                newData.diskIOUsage = self.getDiskIOUsage()
            }
            if self.args.internet {
                newData.internetUsage = self.getNetworkUsage()
            }
            if self.args.battery {
                newData.batteryUsage = self.getBatteryUsageInfo()
            }

            // 取得完了後、メインスレッドでUIに反映
            DispatchQueue.main.async {
                self.data = newData
                // DebugRichConsole.printSystemMatrix(newData)
            }
        }
    }

    /// GPU使用率を取得する (IOKit経由)
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
                // Device Utilization % が存在する場合はそのまま使用（Intel/Apple Silicon共通の標準的な手法）
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

    /// Macの温度状態（サーマルステータス）を取得する
    private func getThermalState() -> String {
        let state = ProcessInfo.processInfo.thermalState
        switch state {
        case .nominal:
            return "Normal"  // 正常・発熱なし
        case .fair:
            return "Warm"  // 暖かい・ファンが回り始める
        case .serious:
            return "Hot"  // 熱い・パフォーマンス低下の恐れ
        case .critical:
            return "Critical"  // 限界・システム緊急状態
        @unknown default:
            return "Unknown"
        }
    }

    /// システム全体のCPU使用率（%）および各コアの使用率を取得
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

    /// ネットワーク（Wi-Fi等）の通信速度（上り/下り）を取得する
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

            // ループバック(lo0)などの内部通信は除外し、実際の物理ネットワーク通信のみを計測
            if name.hasPrefix("lo") { continue }

            // AF_LINK のデータ構造の中に送受信バイト数が入っている
            if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                if let data = interface.ifa_data {
                    let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                    currentInput &+= UInt64(networkData.ifi_ibytes)
                    currentOutput &+= UInt64(networkData.ifi_obytes)
                }
            }
        }
        freeifaddrs(ifaddr)

        // 初回呼び出し時は基準点を作成して0を返す
        if isFirstNetworkFetch {
            prevNetworkInput = currentInput
            prevNetworkOutput = currentOutput
            isFirstNetworkFetch = false
            return NetworkUsageInfo(uploadBytesPerSecond: 0, downloadBytesPerSecond: 0)
        }

        // 前回(1秒前)からの差分を算出
        let diffInput = currentInput >= prevNetworkInput ? currentInput - prevNetworkInput : 0
        let diffOutput = currentOutput >= prevNetworkOutput ? currentOutput - prevNetworkOutput : 0

        prevNetworkInput = currentInput
        prevNetworkOutput = currentOutput

        return NetworkUsageInfo(uploadBytesPerSecond: diffOutput, downloadBytesPerSecond: diffInput)
    }

    /// ディスクI/O速度（Read/Write）を取得する
    private func getDiskIOUsage() -> DiskUsageInfo? {
        let matchingDict = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == kIOReturnSuccess else { return nil }
        
        var currentRead: UInt64 = 0
        var currentWrite: UInt64 = 0
        
        var object: io_object_t = IOIteratorNext(iterator)
        while object != 0 {
            if let props = IORegistryEntryCreateCFProperty(object, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
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

    // return value - = 放電
    // return value + = 充電
    // これらをisChargingの値に
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
                        _isCharging = (_amperage >= 0) // 0以上の場合は充電・AC電源駆動
                        _activeWatts = Float(abs(_amperage) * _voltage) / 1_000_000.0
                    }
                }
                IOObjectRelease(object)
                object = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            return WatInfo(activeWatts: _activeWatts, amperage: _amperage, voltage: _voltage, isCharging: _isCharging)
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
    
    /// バッテリー関連の情報を一括取得して返す
    private func getBatteryUsageInfo() -> BatteryUsageInfo {
        return BatteryUsageInfo(
            isCharging: getIsNowCharging(),
            currentCapacity: currentBatteryCharged(),
            timeToEmpty: batteryTimeLeft(),
            timeToFull: chargingTimeLeft(),
            wattInfo: getChargingPowerWat()
        )
    }

}

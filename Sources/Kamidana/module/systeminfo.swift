import Darwin
import Foundation
import Combine

// ユーザーが設定できる表示項目（JSON等から変換可能）
struct SystemMatrixArgs: Codable {
    var cpu: Bool = false
    var memory: Bool = false
    var disk: Bool = false
    var internet: Bool = false
    var power: Bool = false
    var gpu: Bool = false
}

// 取得したシステムデータを一括で保持する構造体
struct SystemMatrixData {
    var cpuUsage: CPUUsageInfo?
    var memoryMB: UInt64?
    var processCount: Int?
    var threadCount: Int?
    var diskSpace: String?
    // TODO: internet, power, gpu のデータを追加
}

// CPUの使用率をまとめる構造体
struct CPUUsageInfo {
    var total: Float
    var perCore: [Float]
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
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorCount: mach_msg_type_number_t = 0
    private var previousCPUUsage = CPUUsageInfo(total: 0.0, perCore: [])
    private var timer: AnyCancellable?
    
    private let powerMatrixExecutePath = "/usr/bin/powermetrics"

    init(args: SystemMatrixArgs) {
        self.args = args
    }

    /// 定期モニタリングを開始する
    func startMonitoring() {
        if args.cpu {
            _ = getCPUUsage() // 初回の基準点を作成
        }
        
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
        var newData = SystemMatrixData()
        
        if args.cpu {
            newData.cpuUsage = getCPUUsage()
            let procData = getProcessAndThreadCount()
            newData.processCount = procData.processes
            newData.threadCount = procData.threads
        }
        
        if args.memory {
            newData.memoryMB = getMemoryUsed()
        }
        
        if args.disk {
            newData.diskSpace = getDiskSpace(.used)
        }
        
        if args.power {
            // powermetrics を実行（※実行にはRoot権限が必要です）
            // runPowerMetricsCommand()
        }
        
        // 取得したデータをViewに反映
        self.data = newData
    }

    // MARK: - 個別の取得ロジック

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
            let u = UInt32(bitPattern: info[index + Int(CPU_STATE_USER)]) &- UInt32(bitPattern: prev[index + Int(CPU_STATE_USER)])
            let s = UInt32(bitPattern: info[index + Int(CPU_STATE_SYSTEM)]) &- UInt32(bitPattern: prev[index + Int(CPU_STATE_SYSTEM)])
            let i_tick = UInt32(bitPattern: info[index + Int(CPU_STATE_IDLE)]) &- UInt32(bitPattern: prev[index + Int(CPU_STATE_IDLE)])
            let n = UInt32(bitPattern: info[index + Int(CPU_STATE_NICE)]) &- UInt32(bitPattern: prev[index + Int(CPU_STATE_NICE)])

            let coreTotal = Double(u &+ s &+ i_tick &+ n)
            if coreTotal > 0.0 {
                let coreUsage = Double(u &+ s &+ n) / coreTotal
                currentCoreUsages.append(Float(coreUsage * 100.0))
            } else {
                currentCoreUsages.append(previousCPUUsage.perCore.indices.contains(i) ? previousCPUUsage.perCore[i] : 0.0)
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
        let prevSize = Int(prevProcessorCount * UInt32(CPU_STATE_MAX)) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevSize))

        prevProcessorInfo = info
        prevProcessorCount = processorCount
        previousCPUUsage = CPUUsageInfo(total: Float(usage * 100.0), perCore: currentCoreUsages)

        return previousCPUUsage
    }

    private func getMemoryUsed() -> MegaByte? {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
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
            let size = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
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
        
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let total = (attributes[.systemSize] as? NSNumber)?.int64Value,
              let free = (attributes[.systemFreeSize] as? NSNumber)?.int64Value else {
            return "0 MB"
        }
        
        switch type {
        case .total: return byteUnitStringConverted(total)
        case .free: return byteUnitStringConverted(free)
        case .used: return byteUnitStringConverted(total - free)
        }
    }
    
    // MARK: - PowerMetrics (高度な情報)
    
    /// ※このコマンドを実行するには Root 権限 (sudo) が必要です
    private func runPowerMetricsCommand() {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: powerMatrixExecutePath)
        process.arguments = ["-f", "plist", "-n", "1"]
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let rawData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: rawData, encoding: .utf8) {
                print("PowerMetrics Output:", output)
                // TODO: plist形式で出力されたデータをパースして変数に格納する
            }
        } catch {
            print("Failed to run powermetrics: \(error)")
        }
    }
}

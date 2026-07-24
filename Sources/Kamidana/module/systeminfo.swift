import Darwin
import Foundation

enum DiskSpaceType {
    case total
    case free
    case used
}

// CPUの使用率をまとめる構造体
struct CPUUsageInfo {
    var total: Float  // 全体の使用率
    var perCore: [Float]  // コアごとの使用率の配列
}

class systemInfo {
    typealias MegaByte = UInt64

    // CPU計算用の状態保存
    private var prevProcessorInfo: processor_info_array_t?
    private var prevProcessorCount: mach_msg_type_number_t = 0
    private var previousUsage = CPUUsageInfo(total: 0.0, perCore: [])

    /// システム全体のCPU使用率（%）および各コアの使用率を取得
    func getCPUUsage() -> CPUUsageInfo {
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

        guard result == KERN_SUCCESS, let info = processorInfo else { return previousUsage }

        // 初回呼び出し時は状態を保存して0.0を返す
        guard let prev = prevProcessorInfo else {
            prevProcessorInfo = info
            prevProcessorCount = processorCount
            previousUsage.perCore = Array(repeating: 0.0, count: Int(processorCount))
            return previousUsage
        }

        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        var totalNice: UInt32 = 0

        var currentCoreUsages: [Float] = []

        // 全コアのチック数を安全に足し合わせる（&- はオーバーフロー対策の引き算）
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

            // コア単体の使用率を計算
            let coreTotal = Double(u &+ s &+ i_tick &+ n)
            if coreTotal > 0.0 {
                let coreUsage = Double(u &+ s &+ n) / coreTotal
                currentCoreUsages.append(Float(coreUsage * 100.0))
            } else {
                currentCoreUsages.append(
                    previousUsage.perCore.indices.contains(i) ? previousUsage.perCore[i] : 0.0)
            }

            // 全体合計へ加算
            totalUser &+= u
            totalSystem &+= s
            totalIdle &+= i_tick
            totalNice &+= n
        }

        let totalDiff = Double(totalUser &+ totalSystem &+ totalIdle &+ totalNice)

        // 呼び出し間隔が短すぎる場合の対策
        if totalDiff < 1.0 {
            let size = Int(processorMsgCount) * MemoryLayout<integer_t>.size
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(size))
            return previousUsage
        }

        let usage = Double(totalUser &+ totalSystem &+ totalNice) / totalDiff

        // メモリリークを防ぐため、前回分のC言語ポインタを解放
        let prevSize =
            Int(prevProcessorCount * UInt32(CPU_STATE_MAX)) * MemoryLayout<integer_t>.size
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(prevSize))

        // 今回の情報を保存
        prevProcessorInfo = info
        prevProcessorCount = processorCount
        previousUsage = CPUUsageInfo(total: Float(usage * 100.0), perCore: currentCoreUsages)

        return previousUsage
    }

    /// システム全体の使用済みメモリ（MB）を取得
    func getMemoryUsed() -> MegaByte? {
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

            let totalUsedBytes = wired + active + compressed
            return totalUsedBytes / 1024 / 1024
        }

        return nil
    }

    /// 現在起動している全プロセス数と、システム全体の合計スレッド数を取得する
    func getProcessAndThreadCount() -> (processes: Int, threads: Int) {
        // macOSのプロセス情報を格納するのに必要なバッファサイズを取得
        var pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        let count = pidsSize / Int32(MemoryLayout<pid_t>.size)

        // PID一覧を取得
        var pids = [pid_t](repeating: 0, count: Int(count))
        pidsSize = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, pidsSize)

        var totalThreads = 0
        var totalProcesses = 0

        // 全PIDをループして、スレッド数を加算していく
        for pid in pids {
            if pid == 0 { continue }
            totalProcesses += 1

            var taskInfo = proc_taskinfo()
            let size = proc_pidinfo(
                pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))

            // 権限などの問題で取得できなかったプロセスは無視（自身や権限のあるプロセスのみ集計）
            // ※ アクティビティモニタの全ユーザープロセス数と近い値になります
            if size == Int32(MemoryLayout<proc_taskinfo>.size) {
                totalThreads += Int(taskInfo.pti_threadnum)
            }
        }

        return (processes: totalProcesses, threads: totalThreads)
    }

    func getDiskSpace(_ type: DiskSpaceType) -> String {
        let byteUnitStringConverted: (Int64) -> String = { size in
            ByteCountFormatter.string(
                fromByteCount: size, countStyle: ByteCountFormatter.CountStyle.binary)
        }
        switch type {
        case .total:
            return byteUnitStringConverted(totalSpace)
        case .free:
            return byteUnitStringConverted(freeSpace)
        case .used:
            return byteUnitStringConverted(usedSpace)
        }
    }

    private var totalSpace: Int64 {
        guard let attributes = systemAttributes,
            let size = (attributes[FileAttributeKey.systemSize] as? NSNumber)?.int64Value
        else { return 0 }
        return size
    }

    private var freeSpace: Int64 {
        guard let attributes = systemAttributes,
            let size = (attributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
        else { return 0 }
        return size
    }

    private var usedSpace: Int64 {
        return totalSpace - freeSpace
    }

    private var systemAttributes: [FileAttributeKey: Any]? {
        return try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
    }
}

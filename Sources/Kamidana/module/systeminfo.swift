import Combine
import Darwin
import Foundation

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
    var gpuUsage: GPUUsageInfo?
    var powerUsage: PowerUsageInfo?
    var internetUsage: NetworkUsageInfo?
}

// 通信速度をまとめる構造体
struct NetworkUsageInfo {
    var uploadBytesPerSecond: UInt64
    var downloadBytesPerSecond: UInt64
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

// 電力量をまとめる構造体
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

    // Powermetricsの連続ストリームプロセス管理用
    private var powerMetricsProcess: Process?
    private var powerMetricsBuffer = Data()

    // Powermetricsから取得した最新の全データ（辞書型）
    private var latestPowerMetricsDict: [String: Any]?

    private let powerMatrixExecutePath = "/usr/bin/powermetrics"

    init(args: SystemMatrixArgs) {
        self.args = args
    }

    /// 定期モニタリングを開始する
    func startMonitoring() {
        // CPU, GPU, Power のいずれかが必要な場合のみ Powermetrics を起動する
        if args.cpu || args.gpu || args.power {
            startPowerMetricsStream()
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

        powerMetricsProcess?.terminate()
        powerMetricsProcess = nil
    }

    /// 設定(args)に基づいて、必要なデータだけを取得する
    func fetchData() {
        // バックグラウンドで非同期に実行
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            var newData = self.data  // 現在のデータをベースにする

            // 1. Powermetrics由来のデータ抽出
            if let pmDict = self.latestPowerMetricsDict {
                if self.args.cpu {
                    newData.cpuUsage = self.extractCPUUsage(from: pmDict)
                    let procData = self.getProcessAndThreadCount()
                    newData.processCount = procData.processes
                    newData.threadCount = procData.threads
                }
                if self.args.gpu {
                    newData.gpuUsage = self.extractGPUUsage(from: pmDict)
                }
                if self.args.power {
                    newData.powerUsage = self.extractPowerUsage(from: pmDict)
                }
            }

            // 2. その他のAPI由来のデータ抽出
            if self.args.memory {
                newData.memoryMB = self.getMemoryUsed()
            }

            if self.args.disk {
                newData.diskSpace = self.getDiskSpace(.used)
            }

            if self.args.internet {
                newData.internetUsage = self.getNetworkUsage()
            }

            // 取得完了後、メインスレッドでUIに反映
            DispatchQueue.main.async {
                self.data = newData
                self.printRichConsoleOutput(newData)
            }
        }
    }

    // MARK: - コンソール用リッチ出力
    // WARN: 本番ビルドで入れないように
    private func printRichConsoleOutput(_ data: SystemMatrixData) {
        // ANSIエスケープシーケンス（色付け）
        let reset = "\u{001B}[0m"
        let bold = "\u{001B}[1m"
        let cyan = "\u{001B}[36m"
        let green = "\u{001B}[32m"
        let yellow = "\u{001B}[33m"
        let red = "\u{001B}[31m"
        let purple = "\u{001B}[35m"
        let blue = "\u{001B}[34m"

        var out =
            "\n\(bold)\(cyan)┏━━━━━━━━━━━━━━━━━━ KAMIDANA MATRIX ━━━━━━━━━━━━━━━━━━┓\(reset)\n"

        // --- CPU ---
        if let cpu = data.cpuUsage {
            let color = cpu.total < 30 ? green : (cpu.total < 70 ? yellow : red)
            out +=
                " \(bold)CPU\(reset)    | Total: \(color)\(String(format: "%5.1f%%", cpu.total))\(reset)\n"

            // コアごとのグラフ（簡易的な棒グラフ）
            var coreGraph = ""
            for core in cpu.perCore {
                let block = core < 20 ? " " : (core < 50 ? "▂" : (core < 80 ? "▆" : "█"))
                let cColor = core < 30 ? green : (core < 70 ? yellow : red)
                coreGraph += "\(cColor)\(block)\(reset)"
            }
            out += " \(bold)CORES\(reset)  | [\(coreGraph)]\n"
        }

        // --- Memory ---
        if let mem = data.memoryMB {
            out +=
                " \(bold)MEMORY\(reset) | \(purple)\(String(format: "%.1f GB", Double(mem) / 1024.0))\(reset) in use\n"
        }

        // --- Network ---
        if let net = data.internetUsage {
            out +=
                " \(bold)NET\(reset)    | \(blue)↑ \(formatBytes(net.uploadBytesPerSecond))/s\(reset)  \(green)↓ \(formatBytes(net.downloadBytesPerSecond))/s\(reset)\n"
        }

        // --- Process/Threads ---
        if let p = data.processCount, let t = data.threadCount {
            out += " \(bold)TASKS\(reset)  | \(p) Processes, \(t) Threads\n"
        }

        out += "\(bold)\(cyan)┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\(reset)"
        print(out)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - PowerMetrics Continuous Stream

    /// powermetrics をバックグラウンドで起動し、-i (インターバル) 指定で垂れ流し出力を読み取り続ける
    private func startPowerMetricsStream() {
        guard powerMetricsProcess == nil else { return }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: powerMatrixExecutePath)

        // 必要な情報だけをサンプリングして負荷を下げる
        var samplers: [String] = []
        if args.cpu || args.gpu || args.power {
            samplers.append("cpu_power")  // CPU, GPU, Power はすべて cpu_power サンプラーに含まれることが多い
        }

        let samplerArgs = samplers.joined(separator: ",")

        if !samplerArgs.isEmpty {
            process.arguments = ["-f", "plist", "-i", "1000", "-s", samplerArgs]
        } else {
            process.arguments = ["-f", "plist", "-i", "1000"]
        }

        process.standardOutput = pipe
        process.standardError = Pipe()

        powerMetricsProcess = process

        // 非同期でパイプからデータが送られてくるたびに読み取る
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let incomingData = handle.availableData
            guard !incomingData.isEmpty else { return }
            self?.processIncomingPowerMetricsData(incomingData)
        }

        do {
            try process.run()
        } catch {
            print("Failed to start powermetrics stream: \(error)")
        }
    }

    /// 受け取った生データをバッファに貯め、1回分のXMLが完了するごとにパースする
    private func processIncomingPowerMetricsData(_ newData: Data) {
        powerMetricsBuffer.append(newData)

        // powermetricsの連続出力は、1回分のデータの末尾に必ず NUL文字 (0x00) が入る仕様
        while let nullIndex = powerMetricsBuffer.firstIndex(of: 0x00) {
            // NUL文字までの1ブロック（完全な1回分のXML）を切り出し
            let chunk = powerMetricsBuffer[..<nullIndex]
            powerMetricsBuffer.removeSubrange(...nullIndex)

            // 非同期でパース処理へ
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.parsePowerMetricsChunk(chunk)
            }
        }
    }

    /// 1回分のXMLデータをまるごとパースして辞書として保存する
    private func parsePowerMetricsChunk(_ data: Data) {
        do {
            if let plist = try PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [String: Any]
            {
                // パース済みの辞書をそのまま保存
                self.latestPowerMetricsDict = plist
            }
        } catch {
            print(
                "Plist Serialization Error (Chunk size: \(data.count)): \(error.localizedDescription)"
            )
        }
    }

    // MARK: - データ抽出ロジック (Extractors)

    /// 辞書データからCPU情報を抽出
    private func extractCPUUsage(from dict: [String: Any]) -> CPUUsageInfo? {
        guard let processor = dict["processor"] as? [String: Any],
            let clusters = processor["clusters"] as? [[String: Any]]
        else {
            return nil
        }

        var coreUsages: [Float] = []
        for cluster in clusters {
            if let cpus = cluster["cpus"] as? [[String: Any]] {
                for cpu in cpus {
                    if let activeRatio = cpu["active_ratio"] as? Double {
                        coreUsages.append(Float(activeRatio * 100.0))
                    } else if let idleRatio = cpu["idle_ratio"] as? Double {
                        coreUsages.append(Float((1.0 - idleRatio) * 100.0))
                    }
                }
            }
        }

        if !coreUsages.isEmpty {
            let total = coreUsages.reduce(0, +) / Float(coreUsages.count)
            return CPUUsageInfo(total: total, perCore: coreUsages)
        }
        return nil
    }

    /// 辞書データからGPU情報を抽出
    private func extractGPUUsage(from dict: [String: Any]) -> GPUUsageInfo? {
        // ※ Macによってキーが "gpu" や "processor" 内のクラスタになっている場合があります
        // M1などのApple Siliconでは processor の中に含まれることが多いです
        if let processor = dict["processor"] as? [String: Any],
            let activeRatio = processor["gpu_active_ratio"] as? Double
        {  // 仮のキー名
            return GPUUsageInfo(activeRatio: Float(activeRatio * 100.0))
        }
        return nil
    }

    /// 辞書データから消費電力(Power)情報を抽出
    private func extractPowerUsage(from dict: [String: Any]) -> PowerUsageInfo? {
        if let processor = dict["processor"] as? [String: Any],
            let packageWatts = processor["package_watts"] as? Double
        {  // 仮のキー名
            return PowerUsageInfo(packageWatts: Float(packageWatts))
        }
        return nil
    }

    // MARK: - 個別のAPI取得ロジック (OS標準API)

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

    // MARK: - PowerMetrics (高度な情報)

    // 現在はgetCPUUsageFromPowerMetricsに統合されたため、こちらは削除または将来の拡張用に残します
}

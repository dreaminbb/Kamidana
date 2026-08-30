import Foundation

enum DebugRichConsole {
    #if DEBUG
        static var isEnabled = true
    #else
        static var isEnabled = false
    #endif

    private static let reset = "\u{001B}[0m"
    private static let bold = "\u{001B}[1m"
    private static let cyan = "\u{001B}[36m"
    private static let green = "\u{001B}[32m"
    private static let yellow = "\u{001B}[33m"
    private static let red = "\u{001B}[31m"
    private static let purple = "\u{001B}[35m"
    private static let blue = "\u{001B}[34m"

    static func printSystemMatrix(_ data: SystemMatrixData) {
        guard isEnabled else { return }

        var out =
            "\n\(bold)\(cyan)┏━━━━━━━━━━━━━━━━━━ KAMIDANA MATRIX ━━━━━━━━━━━━━━━━━━┓\(reset)\n"

        if let cpu = data.cpuUsage {
            let color = cpu.total < 30 ? green : (cpu.total < 70 ? yellow : red)
            out +=
                " \(bold)CPU\(reset)    | Total: \(color)\(String(format: "%5.1f%%", cpu.total))\(reset)\n"

            var coreGraph = ""
            for core in cpu.perCore {
                let block = core < 20 ? " " : (core < 50 ? "▂" : (core < 80 ? "▆" : "█"))
                let cColor = core < 30 ? green : (core < 70 ? yellow : red)
                coreGraph += "\(cColor)\(block)\(reset)"
            }
            out += " \(bold)CORES\(reset)  | [\(coreGraph)]\n"
        }

        if let mem = data.memoryMB {
            out +=
                " \(bold)MEMORY\(reset) | \(purple)\(String(format: "%.1f GB", Double(mem) / 1024.0))\(reset) in use\n"
        }

        if let net = data.internetUsage {
            out +=
                " \(bold)NET\(reset)    | \(blue)↑ \(formatBytes(net.uploadBytesPerSecond))/s\(reset)  \(green)↓ \(formatBytes(net.downloadBytesPerSecond))/s\(reset)\n"
        }

        if let p = data.processCount, let t = data.threadCount {
            out += " \(bold)TASKS\(reset)  | \(p) Processes, \(t) Threads\n"
        }

        out += "\(bold)\(cyan)┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛\(reset)"
        print(out)
    }

    static func printLaunchAtLoginFailure(action: String, error: Error) {
        guard isEnabled else { return }
        print("\(yellow)[Launch at Login] Failed to \(action): \(error)\(reset)")
    }

    static func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

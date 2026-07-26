import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarWindow: NSWindow!
    let barHeight: CGFloat = 32  // バーの高さは共通で使うので外に出す

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = StatusBarView()

        // 最初のウィンドウ作成
        statusBarWindow = NSWindow(
            contentRect: .zero,  // あとで updateWindowPosition で計算するため最初はzero
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        statusBarWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        statusBarWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        statusBarWindow.backgroundColor = .clear
        statusBarWindow.hasShadow = false
        statusBarWindow.isOpaque = false

        let hostingController = NSHostingController(rootView: contentView)
        statusBarWindow.contentView = hostingController.view

        // ウィンドウの初期位置を計算
        updateWindowPosition()

        statusBarWindow.makeKeyAndOrderFront(nil)
        statusBarWindow.orderFrontRegardless()

        // 【追加】ディスプレイの設定変更（抜き差しや解像度変更）を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateWindowPosition),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // 【追加】スリープからの復帰を監視
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(updateWindowPosition),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    // 【追加】画面の一番上に強制的に再配置する関数
    @objc func updateWindowPosition() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame

        let windowRect = NSRect(
            x: screenRect.minX,
            y: screenRect.maxY - barHeight,
            width: screenRect.width,
            height: barHeight
        )

        // アニメーションなしで即座に正しい位置・サイズにスナップさせる
        statusBarWindow.setFrame(windowRect, display: true)
    }
}

struct StatusBarView: View {
    @State private var currentTime = Date()
    let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // SystemMatrixを初期化（テストとしてCPU, メモリ, ネットワークを true に設定）
    @StateObject private var matrix = SystemMatrix(args: SystemMatrixArgs(
        cpu: true,
        memory: true,
        disk: false,
        internet: true, // ネットワーク通信速度の取得をONに変更
        power: false,
        gpu: false
    ))

    var body: some View {
        HStack(spacing: 0) {
            // 左側：プロセス数とスレッド数を表示（ArgsでCPUがONの場合のみ表示）
            if let procs = matrix.data.processCount, let thds = matrix.data.threadCount {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.grid.2x2")
                        Text("\(procs) Procs")
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                        Text("\(thds) Thds")
                    }
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .padding(.leading, 24)
            }

            Spacer()

            Text("⛩️ Kamidana Custom Status Bar")
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 20) {
                
                // インターネット通信速度（ArgsでONの場合のみ表示）
                if let net = matrix.data.internetUsage {
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle")
                                .foregroundColor(.blue)
                            Text(formatBytes(net.uploadBytesPerSecond) + "/s")
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundColor(.green)
                            Text(formatBytes(net.downloadBytesPerSecond) + "/s")
                        }
                    }
                    // テキストの長さが変わってUIがガタガタ動かないように幅を固定
                    .frame(width: 150, alignment: .trailing)
                }

                // CPU情報（ArgsでONの場合のみ表示）
                if let cpu = matrix.data.cpuUsage {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                        Text(String(format: "%.1f%%", cpu.total))
                    }
                }

                // メモリ情報（ArgsでONの場合のみ表示）
                if let mem = matrix.data.memoryMB {
                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                        Text(String(format: "%.1f GB", Double(mem) / 1024.0))
                    }
                }

                Text(currentTime, style: .time)
                    .fontWeight(.medium)
            }
            .font(.system(size: 13, weight: .regular, design: .monospaced))
            .foregroundColor(.white)
            .padding(.trailing, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12).opacity(0.85))
        .overlay(
            Rectangle()
                .frame(height: 2)
                .foregroundColor(Color.blue.opacity(0.7)),
            alignment: .bottom
        )
        .onAppear {
            matrix.startMonitoring()
        }
        .onReceive(clockTimer) { input in
            currentTime = input
        }
    }
    
    // バイト数を綺麗にフォーマットするヘルパー関数
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary // 1024ベースで計算
        // "Zero KB" のような表示を防ぐ処理
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

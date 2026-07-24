import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarWindow: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = StatusBarView()

        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        let barHeight: CGFloat = 32

        let windowRect = NSRect(
            x: screenRect.minX,
            y: screenRect.maxY - barHeight,
            width: screenRect.width,
            height: barHeight
        )

        statusBarWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        // NSWindow.Level.mainMenu + 1 is usually enough to cover the top bar
        statusBarWindow.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.maximumWindow)))
        statusBarWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        statusBarWindow.backgroundColor = .clear
        statusBarWindow.hasShadow = false
        statusBarWindow.isOpaque = false

        let hostingController = NSHostingController(rootView: contentView)
        statusBarWindow.contentView = hostingController.view

        statusBarWindow.makeKeyAndOrderFront(nil)
        statusBarWindow.orderFrontRegardless()
    }
}

struct StatusBarView: View {
    @State private var currentTime = Date()

    // システム情報を取得するクラスのインスタンスを保持
    @State private var sysInfo = systemInfo()

    // 画面に表示するための状態変数
    @State private var currentCPU: Float = 0.0
    @State private var currentMemoryMB: UInt64 = 0
    @State private var processCount: Int = 0
    @State private var threadCount: Int = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            // 左側：プロセス数とスレッド数を表示
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                    Text("\(processCount) Procs")
                }
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                    Text("\(threadCount) Thds")
                }
            }
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.8))
            .padding(.leading, 24)

            Spacer()

            Text("⛩️ Kamidana Custom Status Bar")
                .font(.system(size: 14, weight: .bold, design: .default))
                .foregroundColor(.white)

            Spacer()

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                    // CPU使用率を小数点第1位まで表示
                    Text(String(format: "%.1f%%", currentCPU))
                }

                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                    // MBをGBに変換して小数点第1位まで表示
                    Text(String(format: "%.1f GB", Double(currentMemoryMB) / 1024.0))
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
        .onReceive(timer) { input in
            // 時計を更新
            currentTime = input

            // 毎秒システム情報を取得して状態を更新する
            // （同じ sysInfo インスタンスを使い回すのでCPU使用率が正しく差分計算される）
            let cpuData = sysInfo.getCPUUsage()
            currentCPU = cpuData.total

            currentMemoryMB = sysInfo.getMemoryUsed() ?? 0

            let procData = sysInfo.getProcessAndThreadCount()
            processCount = procData.processes
            threadCount = procData.threads
        }
    }
}

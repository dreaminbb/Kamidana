import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarWindow: NSWindow!
    let barHeight: CGFloat = 32 // バーの高さは共通で使うので外に出す

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
            contentRect: .zero, // あとで updateWindowPosition で計算するため最初はzero
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

import AppKit
import CoreWLAN
import SwiftUI

// FIX:
// - [ ] ホバーした後にホバーが戻らないでUIが全体が下に下がる

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

    // SystemMatrixを初期化
    @StateObject private var matrix = SystemMatrix(
        args: SystemMatrixArgs(
            cpu: true,
            memory: true,
            disk: true,    // ←追加: ディスクI/O用
            internet: true,
            power: true,   // ←追加: バッテリー計算用
            gpu: true,
            thermal: true,
            battery: true  // ←追加: バッテリーUI用
        ))

    // LocalSendマネージャーを初期化
    @StateObject private var localSend = LocalSendManager()

    // ネットワークマネージャーを初期化
    @StateObject private var netManager = NetworkManager()

    // 音楽マネージャー（メディア再生）を初期化
    @StateObject private var musicManager = MusicPlayingManager()

    // オーディオマネージャーを初期化
    @StateObject private var audioVM = AudioViewModel()

    @State private var showWiFiPopover = false
    @State private var showAudioPopover = false
    @State private var showMicPopover = false
    @State private var selectedSSID: String? = nil
    @State private var wifiPassword = ""
    @State private var connectionStatusMsg = ""

    var body: some View {
        let theme = Theme.catppuccinMocha

        HStack(spacing: 8) {
            LocalSendWidget(localSend: localSend, theme: theme)
            WiFiWidget(netManager: netManager, theme: theme)
            MusicWidget(musicManager: musicManager, theme: theme)
            AudioWidget(audioVM: audioVM, theme: theme)

            Spacer()

            BatteryWidget(matrix: matrix, theme: theme)
            NetworkWidget(matrix: matrix, theme: theme)
            CpuGpuWidget(matrix: matrix, theme: theme)
            MemoryWidget(matrix: matrix, theme: theme)
            DiskWidget(matrix: matrix, theme: theme)
            
            ClockWidget(theme: theme)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            matrix.startMonitoring()
            localSend.scanNetwork()
        }
    }
}
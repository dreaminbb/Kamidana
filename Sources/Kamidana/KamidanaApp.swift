import AppKit
import CoreWLAN
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarWindow: NSWindow!
    let barHeight: CGFloat = 160  // バーの高さは共通で使うので外に出す

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
        // システムの画面情報更新が完了するのを待つために非同期で実行
        DispatchQueue.main.async {
            guard let screen = NSScreen.screens.first else { return }
            let screenRect = screen.frame

            let windowRect = NSRect(
                x: screenRect.minX,
                y: screenRect.maxY - self.barHeight,
                width: screenRect.width,
                height: self.barHeight
            )

            // アニメーションなしで即座に正しい位置・サイズにスナップさせる
            self.statusBarWindow.setFrame(windowRect, display: true)
        }
    }
}

struct StatusBarView: View {
    // SystemMatrixを初期化
    @StateObject private var matrix = SystemMatrix(
        args: SystemMatrixArgs(
            cpu: true,
            memory: true,
            disk: true,  // ←追加: ディスクI/O用
            internet: true,
            power: true,  // ←追加: バッテリー計算用
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
    @StateObject private var uiSettings = UISettingsStore()

    @State private var isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()

    var body: some View {
        let theme = Theme.catppuccinMocha
        let compactMode = uiSettings.resolveCompactMode(isBuiltInDisplay: isBuiltInDisplay)
        let _ = print("👉 UI再描画: isBuiltInDisplay=\(isBuiltInDisplay), compactMode=\(compactMode)")

        ZStack(alignment: .top) {
            // 左側のウィジェット群
            HStack(spacing: compactMode ? 6 : 8) {
                // LocalSendWidget(localSend: localSend, theme: theme)
                WiFiWidget(netManager: netManager, theme: theme)
                AudioWidget(audioVM: audioVM, theme: theme)
            }
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)

            // 右側のウィジェット群
            HStack(
                spacing: compactMode ? 6 : 8,
                content: {
                    if compactMode {
                        // コンパクトモードでは一部ウィジェットをFold（折りたたみ）する
                        CpuWidget(matrix: matrix, theme: theme)
                        MemoryWidget(matrix: matrix, theme: theme)
                        BatteryWidget(matrix: matrix, theme: theme)
                        ClockWidget(theme: theme)
                        FoldedWidgetsButton(matrix: matrix, theme: theme)
                    } else {
                        // 通常モードでは全て展開
                        NetworkWidget(matrix: matrix, theme: theme)
                        CpuWidget(matrix: matrix, theme: theme)
                        GpuWidget(matrix: matrix, theme: theme)
                        MemoryWidget(matrix: matrix, theme: theme)
                        DiskWidget(matrix: matrix, theme: theme)
                        BatteryWidget(matrix: matrix, theme: theme)
                        ClockWidget(theme: theme)
                    }
                }
            )
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 10)

            // 中央の音楽ウィジェット（モードによって高さを変える）
            MusicWidget(musicManager: musicManager, theme: theme)
                .fixedSize()
                // コンパクトモード（内蔵画面）の場合はノッチを避けて下（top: 40）へ、
                // 通常モード（外部画面）の場合はノッチがないため、最上部中央（top: 2）に配置する
                .padding(.top, compactMode ? 40 : 2)
                .zIndex(100)
        }
        .environment(\.compactMode, compactMode)
        .font(.system(size: compactMode ? 11 : 12, weight: .semibold, design: .monospaced))
        .frame(maxWidth: .infinity, maxHeight: 200, alignment: .top)
        .background(Color.clear)
        .onAppear {
            matrix.startMonitoring()
            localSend.scanNetwork()
            isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in
            // 通知が飛んできた直後はシステム内部の画面情報(NSScreen.screens)が
            // まだ更新されていないことがあるため、非同期で一拍遅らせて判定する
            DispatchQueue.main.async {
                isBuiltInDisplay = DisplayDetector.isBuiltInMainDisplay()
                print("Updated isBuiltInDisplay: \(isBuiltInDisplay)")
            }
        }
    }
}

private struct FoldedWidgetsButton: View {
    @ObservedObject var matrix: SystemMatrix
    let theme: Theme

    @State private var showPopover = false

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            Image(systemName: "list.bullet")
                .foregroundColor(theme.subtext1)
        }
        .buttonStyle(.plain)
        .SmoothUIModule(theme: theme)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Folded Widgets")
                    .font(.headline)
                    .foregroundColor(theme.text)
                NetworkWidget(matrix: matrix, theme: theme)
                GpuWidget(matrix: matrix, theme: theme)
                DiskWidget(matrix: matrix, theme: theme)
            }
            .padding()
            .background(theme.base)
        }
    }
}

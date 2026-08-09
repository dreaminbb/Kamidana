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
            // LocalSend デバイスが見つかった場合の表示（テスト用）
            if !localSend.discoveredDevices.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.circle.fill")
                        .foregroundColor(theme.blue)
                    Text("\(localSend.discoveredDevices.count) Devices")
                        .foregroundColor(theme.text)
                }
                .hyprlandModule(theme: theme)
            }

            // Wi-Fi接続状態ボタン（クリックでWi-Fiリストを表示）
            Button(action: {
                showWiFiPopover.toggle()
                if showWiFiPopover {
                    netManager.scanForNetworks()
                }
            }) {
                HStack(spacing: 4) {
                    Image(
                        systemName: netManager.currentConnection == "WIFI"
                            ? "wifi"
                            : (netManager.currentConnection == "LAN" ? "network" : "wifi.slash"))
                    Text(netManager.currentConnection)
                }
                .foregroundColor(
                    netManager.currentConnection != "OFF" ? theme.text : theme.subtext0)
            }
            .buttonStyle(.plain)
            .hyprlandModule(theme: theme)
            .popover(isPresented: $showWiFiPopover, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Wi-Fi Networks")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            netManager.scanForNetworks()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 5)

                    if let ssid = selectedSSID {
                        // ▼ パスワード入力画面 ▼
                        VStack(spacing: 12) {
                            Text("\(ssid) に接続")
                                .font(.subheadline)

                            SecureField("パスワード", text: $wifiPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 230)

                            if !connectionStatusMsg.isEmpty {
                                Text(connectionStatusMsg)
                                    .font(.caption)
                                    .foregroundColor(
                                        connectionStatusMsg.contains("成功") ? theme.green : theme.red
                                    )
                            }

                            HStack {
                                Button("キャンセル") {
                                    selectedSSID = nil
                                    wifiPassword = ""
                                    connectionStatusMsg = ""
                                }
                                Spacer()
                                Button("接続") {
                                    connectionStatusMsg = "接続中..."
                                    // UIが固まらないように裏側で接続処理を行う
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        let result = netManager.connectWIFI(
                                            ssid: ssid, password: wifiPassword)
                                        DispatchQueue.main.async {
                                            switch result {
                                            case .success(_):
                                                connectionStatusMsg = "✅ 接続成功！"
                                                // 1秒後にポップオーバーを閉じて状態をリセット
                                                DispatchQueue.main.asyncAfter(
                                                    deadline: .now() + 1.0
                                                ) {
                                                    showWiFiPopover = false
                                                    selectedSSID = nil
                                                    wifiPassword = ""
                                                    connectionStatusMsg = ""
                                                }
                                            case .failure(let error):
                                                connectionStatusMsg =
                                                    "❌ 失敗: \(error.localizedDescription)"
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(wifiPassword.isEmpty)  // パスワードが空の時は押せないようにする
                            }
                            .frame(width: 230)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        // ▲ パスワード入力画面おわり ▲
                    } else if netManager.availableNetworks.isEmpty {
                        Text("ネットワークを検索中...")
                            .foregroundColor(theme.subtext0)
                            .frame(width: 250, alignment: .center)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                // もしパスワードなしの自動接続中などのメッセージがあれば表示
                                if !connectionStatusMsg.isEmpty && selectedSSID == nil {
                                    Text(connectionStatusMsg)
                                        .font(.caption)
                                        .foregroundColor(
                                            connectionStatusMsg.contains("✅")
                                                ? theme.green
                                                : (connectionStatusMsg.contains("❌")
                                                    ? theme.red : theme.yellow)
                                        )
                                        .padding(.bottom, 5)
                                }

                                ForEach(netManager.availableNetworks, id: \.bssid) { network in
                                    // Wi-Fiリストの各行をボタンにしてクリック可能にする
                                    Button(action: {
                                        if let ssid = network.ssid {
                                            if netManager.isKnownNetwork(ssid: ssid) {
                                                // 過去に接続したことがある場合はパスワード不要で即座に接続
                                                connectionStatusMsg = "自動接続中: \(ssid)..."
                                                DispatchQueue.global(qos: .userInitiated).async {
                                                    let result = netManager.connectWIFI(
                                                        ssid: ssid, password: nil)
                                                    DispatchQueue.main.async {
                                                        switch result {
                                                        case .success(_):
                                                            connectionStatusMsg = "✅ 接続しました！"
                                                            DispatchQueue.main.asyncAfter(
                                                                deadline: .now() + 1.0
                                                            ) {
                                                                showWiFiPopover = false
                                                                connectionStatusMsg = ""
                                                            }
                                                        case .failure(let error):
                                                            connectionStatusMsg =
                                                                "❌ 失敗: \(error.localizedDescription)"
                                                        }
                                                    }
                                                }
                                            } else {
                                                // 初めてのネットワークの場合はパスワード入力画面へ
                                                selectedSSID = ssid
                                                wifiPassword = ""
                                                connectionStatusMsg = ""
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "wifi")
                                            Text(network.ssid ?? "Hidden")
                                                .lineLimit(1)
                                            Spacer()
                                            Text("\(network.rssiValue) dBm")
                                                .font(.caption)
                                                .foregroundColor(theme.subtext0)
                                        }
                                        .frame(width: 230)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(theme.surface0)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 300)  // リストが長すぎないように高さを制限
                    }
                }
                .padding()
                .background(theme.base)  // ポップオーバーの背景もテーマに合わせる
            }

            // 🎵 音楽再生UI (Hyprlandスタイルモジュール)
            MusicWidget(musicManager: musicManager)

            // 🔊 オーディオ入出力UIモジュール
            HStack(spacing: 12) {
                // 出力 (スピーカー)
                HStack(spacing: 6) {
                    Button(action: { audioVM.toggleOutputMute() }) {
                        Image(
                            systemName: audioVM.isOutputMuted
                                ? "speaker.slash.fill" : "speaker.wave.2.fill"
                        )
                        .foregroundColor(audioVM.isOutputMuted ? theme.red : theme.blue)
                    }
                    .buttonStyle(.plain)

                    Button(action: { showAudioPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f%%", audioVM.outputVolume * 100))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.text)
                                .frame(width: 30, alignment: .trailing)

                            Text(audioVM.outputFormat)
                                .font(.system(size: 9))
                                .foregroundColor(theme.subtext0)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAudioPopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Output Devices")
                                .font(.headline)
                                .foregroundColor(theme.text)
                                .padding(.bottom, 5)

                            HStack {
                                Image(systemName: "speaker.fill").foregroundColor(theme.subtext0)
                                    .font(.system(size: 10))
                                Slider(
                                    value: Binding(
                                        get: { audioVM.outputVolume },
                                        set: { audioVM.setOutputVolume($0) }), in: 0.0...1.0
                                )
                                .frame(width: 150).accentColor(theme.blue)
                                Image(systemName: "speaker.wave.3.fill").foregroundColor(
                                    theme.subtext0
                                ).font(.system(size: 10))
                            }
                            .padding(.bottom, 5)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(audioVM.outputDevices) { device in
                                        Button(action: { audioVM.changeOutputDevice(device) }) {
                                            HStack {
                                                Image(
                                                    systemName: audioVM.currentOutputDevice?.id
                                                        == device.id
                                                        ? "checkmark.circle.fill" : "circle"
                                                )
                                                .foregroundColor(
                                                    audioVM.currentOutputDevice?.id == device.id
                                                        ? theme.blue : theme.subtext0)
                                                Text(device.name).foregroundColor(theme.text)
                                                Spacer()
                                            }
                                            .frame(width: 200).padding(.vertical, 4).padding(
                                                .horizontal, 8
                                            )
                                            .background(theme.surface0).cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                        }
                        .padding()
                        .background(theme.base)
                    }
                }

                // 入力 (マイク)
                HStack(spacing: 6) {
                    Button(action: { audioVM.toggleInputMute() }) {
                        Image(systemName: audioVM.isInputMuted ? "mic.slash.fill" : "mic.fill")
                            .foregroundColor(audioVM.isInputMuted ? theme.red : theme.peach)
                    }
                    .buttonStyle(.plain)

                    Button(action: { showMicPopover.toggle() }) {
                        HStack(spacing: 4) {
                            Text(String(format: "%.0f%%", audioVM.inputVolume * 100))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.text)
                                .frame(width: 30, alignment: .trailing)

                            Text(audioVM.inputFormat)
                                .font(.system(size: 9))
                                .foregroundColor(theme.subtext0)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showMicPopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Input Devices")
                                .font(.headline)
                                .foregroundColor(theme.text)
                                .padding(.bottom, 5)

                            HStack {
                                Image(systemName: "mic.fill").foregroundColor(theme.subtext0).font(
                                    .system(size: 10))
                                Slider(
                                    value: Binding(
                                        get: { audioVM.inputVolume },
                                        set: { audioVM.setInputVolume($0) }), in: 0.0...1.0
                                )
                                .frame(width: 150).accentColor(theme.peach)
                                Image(systemName: "mic.and.signal.meter.fill").foregroundColor(
                                    theme.subtext0
                                ).font(.system(size: 10))
                            }
                            .padding(.bottom, 5)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(audioVM.inputDevices) { device in
                                        Button(action: { audioVM.changeInputDevice(device) }) {
                                            HStack {
                                                Image(
                                                    systemName: audioVM.currentInputDevice?.id
                                                        == device.id
                                                        ? "checkmark.circle.fill" : "circle"
                                                )
                                                .foregroundColor(
                                                    audioVM.currentInputDevice?.id == device.id
                                                        ? theme.peach : theme.subtext0)
                                                Text(device.name).foregroundColor(theme.text)
                                                Spacer()
                                            }
                                            .frame(width: 200).padding(.vertical, 4).padding(
                                                .horizontal, 8
                                            )
                                            .background(theme.surface0).cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                        }
                        .padding()
                        .background(theme.base)
                    }
                }
            }
            .hyprlandModule(theme: theme)

            Spacer()

            // 🔋 バッテリーモジュール
            BatteryWidget(matrix: matrix, theme: theme)
            
            // 🌐 ネットワークモジュール
            NetworkWidget(matrix: matrix, theme: theme)
            
            // 📊 システム情報モジュール
            SystemWidget(matrix: matrix, theme: theme)
            
            // 時計モジュール
            Text(currentTime, style: .time)
                .fontWeight(.bold)
                .foregroundColor(theme.text)
                .hyprlandModule(theme: theme)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        // .padding(.horizontal, 10) // いらない
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // アプリケーションウィンドウの全体背景を完全に透明化（モジュールだけが浮くようにする）
        .background(Color.clear)
        .onAppear {
            matrix.startMonitoring()
            // LocalSendのネットワークスキャンを開始
            localSend.scanNetwork()
        }
        .onReceive(clockTimer) { input in
            currentTime = input
        }
    }

    // CPUの使用率に応じてテーマカラーを変えるヘルパー関数
    private func getCPUColor(_ usage: Float, theme: Theme) -> Color {
        if usage < 30.0 { return theme.green }
        if usage < 70.0 { return theme.yellow }
        return theme.red
    }

    // サーマルステータスに応じてテーマカラーを変えるヘルパー関数
    private func getThermalColor(_ state: String, theme: Theme) -> Color {
        switch state {
        case "Normal": return theme.sapphire
        case "Warm": return theme.yellow
        case "Hot", "Critical": return theme.red
        default: return theme.text
        }
    }

    // バイト数を綺麗にフォーマットするヘルパー関数
    private func formatBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .binary  // 1024ベースで計算
        // "Zero KB" のような表示を防ぐ処理
        if bytes == 0 { return "0 KB" }
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

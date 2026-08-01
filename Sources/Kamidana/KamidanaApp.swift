import AppKit
import CoreWLAN
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

    // SystemMatrixを初期化
    @StateObject private var matrix = SystemMatrix(
        args: SystemMatrixArgs(
            cpu: true,
            memory: true,
            disk: false,
            internet: true,
            power: false,
            gpu: true,
            thermal: true,
            battery: true
        ))

    // LocalSendマネージャーを初期化
    @StateObject private var localSend = LocalSendManager()

    // ネットワークマネージャーを初期化
    @StateObject private var netManager = NetworkManager()

    // 音楽マネージャー（メディア再生）を初期化
    @StateObject private var musicManager = MusicPlayingManager()

    @State private var showWiFiPopover = false
    @State private var selectedSSID: String? = nil
    @State private var wifiPassword = ""
    @State private var connectionStatusMsg = ""

    var body: some View {
        HStack(spacing: 12) {
            // LocalSend デバイスが見つかった場合の表示（テスト用）
            if !localSend.discoveredDevices.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.circle.fill")
                        .foregroundColor(.blue)
                    Text("\(localSend.discoveredDevices.count) Devices")
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.4), lineWidth: 1))
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
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(netManager.currentConnection != "OFF" ? 0.3 : 0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.blue.opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
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
                                        connectionStatusMsg.contains("成功") ? .green : .red)
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
                            .foregroundColor(.gray)
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
                                                ? .green
                                                : (connectionStatusMsg.contains("❌")
                                                    ? .red : .yellow)
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
                                                .foregroundColor(.gray)
                                        }
                                        .frame(width: 230)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(Color.white.opacity(0.05))
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
                // ポップオーバーの背景をダークモードに合わせる
                .background(Color(red: 0.15, green: 0.15, blue: 0.18))
            }

            // 🎵 音楽再生UI
            if !musicManager.title.isEmpty {
                HStack(spacing: 6) {
                    if let artwork = musicManager.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .cornerRadius(4)
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(.pink)
                            .frame(width: 20, height: 20)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(musicManager.title)
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .foregroundColor(.white)
                            .frame(maxWidth: 100, alignment: .leading)
                        Text(musicManager.artist)
                            .font(.system(size: 8))
                            .lineLimit(1)
                            .foregroundColor(.gray)
                            .frame(maxWidth: 100, alignment: .leading)
                    }

                    HStack(spacing: 6) {
                        Button(action: {
                            musicManager.changeTrack(direction: .previous)
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            musicManager.pauseMusic()
                        }) {
                            Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            musicManager.changeTrack(direction: .next)
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.white)
                    .padding(.leading, 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }

            // インターネット通信速度
            if let net = matrix.data.internetUsage {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(Color(red: 0.4, green: 0.8, blue: 1.0))
                        Text(formatBytes(net.uploadBytesPerSecond) + "/s")
                            .foregroundColor(.white)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.right")
                            .foregroundColor(Color(red: 0.4, green: 1.0, blue: 0.6))
                        Text(formatBytes(net.downloadBytesPerSecond) + "/s")
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 160, alignment: .center)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
            }

            // GPU情報
            if let gpu = matrix.data.gpuUsage {
                let gpuColor = Color(red: 0.2, green: 0.8, blue: 0.9)
                HStack(spacing: 4) {
                    Image(systemName: "g.circle.fill")
                        .foregroundColor(gpuColor)
                    Text(String(format: "%3.0f%%", gpu.activeRatio))
                        .foregroundColor(gpuColor)
                }
                .frame(width: 60, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(gpuColor.opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(gpuColor.opacity(0.3), lineWidth: 1))
            }

            // CPU情報
            if let cpu = matrix.data.cpuUsage {
                let cpuColor = getCPUColor(cpu.total)
                HStack(spacing: 4) {
                    Image(systemName: "cpu")
                        .foregroundColor(cpuColor)
                    Text(String(format: "%5.1f%%", cpu.total))
                        .foregroundColor(cpuColor)
                }
                .frame(width: 75, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(cpuColor.opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(cpuColor.opacity(0.3), lineWidth: 1))
            }

            // サーマルステータス（温度）
            if let thermal = matrix.data.thermalState {
                let thermalColor = getThermalColor(thermal)
                HStack(spacing: 4) {
                    Image(systemName: "thermometer")
                        .foregroundColor(thermalColor)
                    Text(thermal)
                        .foregroundColor(thermalColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(thermalColor.opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        thermalColor.opacity(0.3), lineWidth: 1))
            }

            // メモリ情報
            if let mem = matrix.data.memoryMB {
                HStack(spacing: 4) {
                    Image(systemName: "memorychip")
                        .foregroundColor(Color(red: 0.8, green: 0.6, blue: 1.0))
                    Text(String(format: "%.1f GB", Double(mem) / 1024.0))
                        .foregroundColor(Color(red: 0.9, green: 0.8, blue: 1.0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.6, green: 0.3, blue: 0.9).opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8).stroke(
                        Color(red: 0.6, green: 0.3, blue: 0.9).opacity(0.4), lineWidth: 1))
            }

            // 時計
            Text(currentTime, style: .time)
                .fontWeight(.bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .padding(.trailing, 20)
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
            // LocalSendのネットワークスキャンを開始
            localSend.scanNetwork()
        }
        .onReceive(clockTimer) { input in
            currentTime = input
        }
    }

    // CPUの使用率に応じて色を動的に変えるヘルパー関数
    private func getCPUColor(_ usage: Float) -> Color {
        if usage < 30.0 { return Color(red: 0.4, green: 1.0, blue: 0.6) }  // 緑
        if usage < 70.0 { return Color(red: 1.0, green: 0.8, blue: 0.2) }  // 黄色
        return Color(red: 1.0, green: 0.4, blue: 0.4)  // 赤
    }

    // サーマルステータスに応じて色を変えるヘルパー関数
    private func getThermalColor(_ state: String) -> Color {
        switch state {
        case "Normal": return Color(red: 0.4, green: 0.8, blue: 1.0)
        case "Warm": return Color(red: 1.0, green: 0.8, blue: 0.2)
        case "Hot", "Critical": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return .white
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

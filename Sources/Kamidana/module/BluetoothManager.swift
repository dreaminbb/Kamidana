import Combine
import Foundation
import IOBluetooth  // クラシックBluetooth（マウスやヘッドホン等）用

// UI等で扱いやすいように共通のデバイス構造体を定義
public struct BluetoothDeviceInfo: Identifiable {
    public let id: String  // MACアドレスをIDとして使用
    public let name: String
    public let isConnected: Bool
    public let isPaired: Bool
    public let device: IOBluetoothDevice  // 実際の接続・切断操作用
}

class BluetoothManager: NSObject, ObservableObject, IOBluetoothDeviceInquiryDelegate {

    // UI側で状態を監視できるように @Published を付与
    @Published var isBluetoothOn = false
    @Published var discoveredDevices: [BluetoothDeviceInfo] = []
    @Published var pairedDevices: [BluetoothDeviceInfo] = []

    private var inquiry: IOBluetoothDeviceInquiry?

    // 定期的に状態を更新するためのタイマー
    private var timer: AnyCancellable?

    override init() {
        super.init()
        checkBluetoothState()
        refreshPairedDevices()

        // 5秒ごとにペアリング済みデバイスの接続状態を更新する
        timer = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshPairedDevices()
            }
    }

    /// Bluetoothの電源状態を確認する
    func checkBluetoothState() {
        // IOBluetoothには直接的な電源確認APIがないため、HostControllerが取得できるかで判定
        if IOBluetoothHostController.default() != nil {
            isBluetoothOn = true
        } else {
            isBluetoothOn = false
        }
    }

    /// Macにペアリングされているすべてのデバイスを取得・更新する
    public func refreshPairedDevices() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            self.pairedDevices = []
            return
        }

        // UIスレッドで更新
        DispatchQueue.main.async {
            self.pairedDevices = devices.map { device in
                BluetoothDeviceInfo(
                    id: device.addressString ?? UUID().uuidString,
                    name: device.name ?? "不明なデバイス",
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired(),
                    device: device
                )
            }
        }
    }

    /// 周辺の新しいBluetoothデバイスをスキャンする
    func startScanning() {
        discoveredDevices.removeAll()
        inquiry?.stop()

        // スキャン用のインスタンスを作成（delegateで結果を受け取る）
        inquiry = IOBluetoothDeviceInquiry(delegate: self)
        inquiry?.inquiryLength = 10  // 10秒間スキャン
        inquiry?.updateNewDeviceNames = true

        if inquiry?.start() == kIOReturnSuccess {
            print("🔍 Bluetoothデバイスのスキャンを開始しました...")
        } else {
            print("❌ スキャンの開始に失敗しました。")
        }
    }

    func stopScanning() {
        inquiry?.stop()
        print("止 スキャンを停止しました。")
    }

    /// 特定のデバイスに接続する
    func connect(to device: IOBluetoothDevice) {
        print("🔄 接続試行中: \(device.name ?? "不明")...")
        // 接続処理はメインスレッドをブロックするため非同期で実行
        DispatchQueue.global(qos: .userInitiated).async {
            let result = device.openConnection()
            DispatchQueue.main.async {
                if result == kIOReturnSuccess {
                    print("✅ 接続成功: \(device.name ?? "不明")")
                } else {
                    print("❌ 接続失敗: \(device.name ?? "不明")")
                }
                self.refreshPairedDevices()
            }
        }
    }

    /// 特定のデバイスから切断する
    func disconnect(from device: IOBluetoothDevice) {
        print("🔄 切断試行中: \(device.name ?? "不明")...")
        // 切断処理
        let result = device.closeConnection()
        if result == kIOReturnSuccess {
            print("⚠️ 切断完了: \(device.name ?? "不明")")
        } else {
            print("❌ 切断失敗: \(device.name ?? "不明")")
        }
        refreshPairedDevices()
    }

    // デバイスを発見した時に呼ばれる
    func deviceInquiryDeviceFound(_ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!) {
        guard let device = device else { return }

        let info = BluetoothDeviceInfo(
            id: device.addressString ?? UUID().uuidString,
            name: device.name ?? "不明なデバイス",
            isConnected: device.isConnected(),
            isPaired: device.isPaired(),
            device: device
        )

        DispatchQueue.main.async {
            // 重複チェックをして追加
            if !self.discoveredDevices.contains(where: { $0.id == info.id }) {
                self.discoveredDevices.append(info)
                print("📱 見つかったデバイス: \(info.name)")
            }
        }
    }

    // デバイスの名前解決が完了した時に呼ばれる
    func deviceInquiryDeviceNameUpdated(
        _ sender: IOBluetoothDeviceInquiry!, device: IOBluetoothDevice!, devicesRemaining: UInt32
    ) {
        // 名前が取得できたらリストを更新する
        DispatchQueue.main.async {
            if let index = self.discoveredDevices.firstIndex(where: {
                $0.id == device.addressString
            }) {
                self.discoveredDevices[index] = BluetoothDeviceInfo(
                    id: device.addressString ?? UUID().uuidString,
                    name: device.name ?? "不明なデバイス",
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired(),
                    device: device
                )
            }
        }
    }

    // スキャンが完了した時に呼ばれる
    func deviceInquiryComplete(_ sender: IOBluetoothDeviceInquiry!, error: IOReturn, aborted: Bool)
    {
        print("✅ Bluetoothスキャン完了")
    }
}

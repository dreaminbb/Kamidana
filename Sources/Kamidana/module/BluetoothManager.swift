import AppKit
import Combine
import Foundation
import IOBluetooth

// UI等で扱いやすいように共通のデバイス構造体を定義
public struct BluetoothDeviceInfo: Identifiable {
    public let id: String  // MACアドレスをIDとして使用
    public let name: String
    public let isConnected: Bool
    public let isPaired: Bool
}

class BluetoothManager: NSObject, ObservableObject {

    // UI側で状態を監視できるように @Published を付与
    @Published var isBluetoothOn = false
    @Published var pairedDevices: [BluetoothDeviceInfo] = []

    // 定期的に状態を更新するためのタイマー
    private var timer: AnyCancellable?

    override init() {
        super.init()
        checkBluetoothState()
        refreshPairedDevices()

        // 3秒ごとにペアリング済みデバイスの接続状態を更新する
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkBluetoothState()
                self?.refreshPairedDevices()
            }
    }

    /// Bluetoothの電源状態を確認する
    func checkBluetoothState() {
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

        // UIスレッドで更新（接続中のデバイスを上位にソート）
        DispatchQueue.main.async {
            self.pairedDevices = devices.map { device in
                BluetoothDeviceInfo(
                    id: device.addressString ?? UUID().uuidString,
                    name: device.name ?? "不明なデバイス",
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired()
                )
            }
            .sorted { $0.isConnected && !$1.isConnected }
        }
    }

    /// macOSのBluetooth設定画面を開く
    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }
}

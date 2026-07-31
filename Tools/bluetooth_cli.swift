import Foundation
import IOBluetooth

print("🔍 MacにペアリングされているBluetoothデバイスを取得中...")
guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice], !devices.isEmpty else {
    print("❌ ペアリングされているデバイスが見つかりません。")
    exit(0)
}

print("\n📱 デバイス一覧:")
for (index, device) in devices.enumerated() {
    let name = device.name ?? "不明"
    let status = device.isConnected() ? "🟢 接続中" : "⚪️ 切断済"
    print("  [\(index)] \(status) - \(name)")
}

print("\n👉 操作したいデバイスの番号を入力してください: ", terminator: "")
guard let input = readLine(), let selectedIndex = Int(input), selectedIndex >= 0, selectedIndex < devices.count else {
    print("❌ 無効な入力です。")
    exit(1)
}

let selectedDevice = devices[selectedIndex]
print("\n選択されたデバイス: \(selectedDevice.name ?? "不明")")

if selectedDevice.isConnected() {
    print("🔄 切断を試みます...")
    let result = selectedDevice.closeConnection()
    if result == kIOReturnSuccess {
        print("✅ 切断成功！")
    } else {
        print("❌ 切断失敗 (エラーコード: \(result))")
    }
} else {
    print("🔄 接続を試みます...")
    // openConnection() は同期処理として完了まで待機します
    let result = selectedDevice.openConnection()
    if result == kIOReturnSuccess {
        print("✅ 接続成功！")
    } else {
        print("❌ 接続失敗 (エラーコード: \(result))")
    }
}

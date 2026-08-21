// import Combine
// import CoreBluetooth
// import XCTest
//
// @testable import KamidanaApp
//
// final class BluetoothManagerTests: XCTestCase {
//     var cancellables = Set<AnyCancellable>()
//
//     func testFetchCurrentConnectedDevices() {
//         let manager = CoreBluetoothManager()
//         let device_list = manager.fetchCurrentConnectedDevices()
//         print(device_list)
//     }

// func testBluetoothStateAndDiscovery() {
//     let manager = CoreBluetoothManager()
//
//     let stateExpectation = XCTestExpectation(description: "Bluetooth状態の更新を待機")
//
//     // Bluetoothの電源状態が変わるのを監視
//     manager.$isBluetoothOn
//         .dropFirst()  // 初期の false を無視
//         .sink { isOn in
//             print("📡 Bluetooth電源ステータス: \(isOn ? "ON (利用可能)" : "OFF (または権限なし)")")
//             stateExpectation.fulfill()
//         }
//         .store(in: &cancellables)
//
//     // マネージャーの初期化応答を待つ（最大3秒）
//     let stateResult = XCTWaiter.wait(for: [stateExpectation], timeout: 3.0)
//
//     if stateResult == .timedOut {
//         print("⚠️ Bluetooth状態の取得がタイムアウトしました。テスト環境にBluetoothモジュールが存在しない可能性があります。")
//     }
//
//     // もしBluetoothがONなら、デバイスが見つかるかどうかもテストする
//     if manager.isBluetoothOn {
//         let discoveryExpectation = XCTestExpectation(description: "デバイス発見を待機")
//
//         manager.$discoveredPeripherals
//             .sink { peripherals in
//                 if !peripherals.isEmpty {
//                     discoveryExpectation.fulfill()
//                 }
//             }
//             .store(in: &cancellables)
//
//         // 5秒間、周囲のデバイスを探す
//         let discResult = XCTWaiter.wait(for: [discoveryExpectation], timeout: 5.0)
//
//         print("✅ 成功: \(manager.discoveredPeripherals.count) 件のBluetoothデバイスが見つかりました。")
//
//         // ログが多すぎるのを防ぐため、最大5件だけ出力
//         for device in manager.discoveredPeripherals.prefix(5) {
//             print("   - デバイス名: \(device.name ?? "不明") (ID: \(device.identifier))")
//         }
//
//         if discResult == .timedOut && manager.discoveredPeripherals.isEmpty {
//             print(
//                 "⚠️ デバイスが0件でした。周囲にペアリング可能なBluetoothデバイス（イヤホンなど）が無いか、ターミナルにBluetoothのアクセス権限がありません。"
//             )
//         }
//     } else {
//         print("⚠️ BluetoothがONではないため、デバイススキャンのテストはスキップされました。")
//         print("👉 対策: Macのシステム設定 > プライバシーとセキュリティ > Bluetooth から、ターミナルへの許可を行ってください。")
//     }
// }
// }

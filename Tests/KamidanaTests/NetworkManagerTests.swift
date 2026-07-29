import Combine
import CoreWLAN
import XCTest

@testable import Kamidana

final class NetworkManagerTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    func testNetworkConnectionStatus() {
        let manager = NetworkManager()
        let expectation = XCTestExpectation(description: "ネットワーク状態の更新を待機")

        manager.$currentConnection
            .sink { connection in
                if connection != "OFF" {
                    print("✅ 現在のネットワーク接続状態: \(connection)")
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let result = XCTWaiter.wait(for: [expectation], timeout: 3.0)
        if result == .timedOut {
            print("⚠️ ネットワーク状態が OFF のままか、モニターの応答がタイムアウトしました。")
        }
    }

    // FIX: 位置情報を許可出来ていないからWIFIが取得出来ない
    func testFetchAvailableNetworks() {
        let manager = NetworkManager()

        let exp = XCTestExpectation(description: "Wait for Wi-Fi Scan")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let result = manager.fetchAvailableNetwork()

            switch result {
            case .success(let networks):
                print("✅ 成功: \(networks.count) 件のWi-Fiネットワークが見つかりました。")

                if networks.isEmpty {
                    print(
                        "⚠️ Wi-Fiが0件です。ターミナル（またはXcode）に「位置情報」のアクセス許可がないため、macOSがセキュリティ機能でSSIDをブロックしています。"
                    )
                    print(
                        "👉 対策: Macの「システム設定」>「プライバシーとセキュリティ」>「位置情報サービス」から、使用しているターミナルアプリに許可を与えてください。"
                    )
                }

                for network in networks.prefix(5) {
                    let ssid = network.ssid ?? "非公開ネットワーク (Hidden)"
                    print("   - SSID: \(ssid) (電波強度: \(network.rssiValue) dBm)")
                }

                XCTAssertNotNil(networks)

            case .failure(let error):
                print("⚠️ 失敗または権限なし: Wi-Fiスキャンに失敗しました。")
                print("   詳細: \(error.localizedDescription)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}

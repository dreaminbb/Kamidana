import Combine
import CoreLocation
import CoreWLAN
import Foundation
import Network

class NetworkManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // UI側でリアルタイムに監視できるように @Published をつける
    @Published var currentConnection: String = "OFF"
    @Published var availableNetworks: [CWNetwork] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // Wi-FiのSSID（名前）を取得するために位置情報権限を要求するマネージャー
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        
        // 位置情報（Wi-Fiの名前取得に必須）の権限リクエスト
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        startMonitoring()
    }

    // 監視を開始する関数
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    if path.usesInterfaceType(.wifi) {
                        self?.currentConnection = "WIFI"
                    } else if path.usesInterfaceType(.wiredEthernet) {
                        self?.currentConnection = "LAN"
                    } else {
                        self?.currentConnection = "OTHER"
                    }
                } else {
                    self?.currentConnection = "OFF"
                }
            }
        }

        // モニターを実際に起動する（これがないと動かない）
        monitor.start(queue: queue)
    }

    /// 周辺の利用可能なWi-Fiネットワークをスキャンして取得し、配列に保存する
    func scanForNetworks() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.fetchAvailableNetwork()
            DispatchQueue.main.async {
                if case .success(let networks) = result {
                    // 電波が強い順（RSSIが大きい順）にソートして保存
                    self?.availableNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }
                } else {
                    self?.availableNetworks = []
                }
            }
        }
    }

    /// 周辺の利用可能なWi-Fiネットワークをスキャンして取得する
    func fetchAvailableNetwork() -> Result<Set<CWNetwork>, Error> {
        let client = CWWiFiClient.shared()

        // Wi-Fiインターフェース（アンテナ）を取得
        guard let interface = client.interface() else {
            let error = NSError(
                domain: "NetworkManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Wi-Fiインターフェースが見つかりません"])
            return .failure(error)
        }

        do {
            // スキャンを実行
            let allNetworks = try interface.scanForNetworks(withName: nil)
            
            // 1. SSIDが空（nil または ""）の非公開ネットワーク（Hidden Network）を除外する
            let publicNetworks = allNetworks.filter { network in
                guard let ssid = network.ssid, !ssid.isEmpty else {
                    return false
                }
                return true
            }
            
            // 2. MacのWi-Fi設定画面と同じように「同じ名前(SSID)のWi-Fi」を重複排除する
            // （メッシュWi-Fi等で同じ名前の電波が複数飛んでいる場合、一番電波が強いものを1つだけ残す）
            var uniqueNetworks = [String: CWNetwork]()
            for network in publicNetworks {
                guard let ssid = network.ssid else { continue }
                
                if let existing = uniqueNetworks[ssid] {
                    // RSSI（電波強度）はマイナスの値（例: -50dBm と -80dBm）。0に近い（大きい）方が電波が強い
                    if network.rssiValue > existing.rssiValue {
                        uniqueNetworks[ssid] = network
                    }
                } else {
                    uniqueNetworks[ssid] = network
                }
            }
            
            return .success(Set(uniqueNetworks.values))
        } catch {
            // 権限エラーやスキャン失敗時はエラーを返す
            return .failure(error)
        }
    }

}

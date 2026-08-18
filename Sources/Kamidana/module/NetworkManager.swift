import Combine
import CoreLocation
import CoreWLAN
import Foundation
import Network
import SystemConfiguration

enum NetworkValueState: Equatable {
    case loading
    case available(String)
    case unavailable(String)
}

struct NetworkInterfaceSnapshot: Equatable {
    let name: String
    let ipv4: String
    let isActive: Bool
}

protocol NetworkAddressSource {
    func interfaceSnapshots() -> [NetworkInterfaceSnapshot]
    func dnsServers() -> [String]
}

protocol PublicIPClient {
    func fetch(completion: @escaping (Result<String, Error>) -> Void)
}

enum NetworkManagerError: LocalizedError, Equatable {
    case wiredConnectionActive
    case wifiInterfaceUnavailable
    case invalidPublicIPResponse

    var errorDescription: String? {
        switch self {
        case .wiredConnectionActive: return "Wi-Fi scanning is disabled while a wired connection is active."
        case .wifiInterfaceUnavailable: return "Wi-Fi interface not found."
        case .invalidPublicIPResponse: return "The public IP service returned an invalid response."
        }
    }
}

final class SystemNetworkAddressSource: NetworkAddressSource {
    func interfaceSnapshots() -> [NetworkInterfaceSnapshot] {
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0 else { return [] }
        defer { freeifaddrs(addressList) }

        var snapshots: [NetworkInterfaceSnapshot] = []
        var pointer = addressList
        while let current = pointer {
            let item = current.pointee
            pointer = item.ifa_next
            guard let address = item.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var mutableAddress = address.pointee
            let result = withUnsafePointer(to: &mutableAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getnameinfo(
                        $0,
                        socklen_t(address.pointee.sa_len),
                        &host,
                        socklen_t(host.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                }
            }
            guard result == 0 else { continue }
            let flags = Int32(item.ifa_flags)
            let name = String(cString: item.ifa_name)
            let ipv4 = String(cString: host)
            guard NetworkManager.isUsableIPv4Interface(name: name, ipv4: ipv4) else {
                continue
            }
            snapshots.append(
                NetworkInterfaceSnapshot(
                    name: name,
                    ipv4: ipv4,
                    isActive: (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
                ))
        }
        return snapshots
    }

    func dnsServers() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "Kamidana" as CFString, nil, nil),
              let value = SCDynamicStoreCopyValue(store, "State:/Network/Global/DNS" as CFString) as? [String: Any],
              let servers = value[kSCPropNetDNSServerAddresses as String] as? [String] else { return [] }
        return servers
    }
}

final class IpifyPublicIPClient: PublicIPClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "https://api64.ipify.org") else {
            completion(.failure(NetworkManagerError.invalidPublicIPResponse))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let data = data,
                  let value = String(data: data, encoding: .utf8),
                  let validValue = NetworkManager.validPublicIPAddress(value) else {
                completion(.failure(NetworkManagerError.invalidPublicIPResponse))
                return
            }
            completion(.success(validValue))
        }.resume()
    }
}

class NetworkManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentConnection: String = "OFF"
    @Published var availableNetworks: [CWNetwork] = []
    @Published private(set) var activeInterfaceName: String?
    @Published private(set) var localIPv4State: NetworkValueState = .unavailable("Not available")
    @Published private(set) var dnsServersState: NetworkValueState = .unavailable("Not available")
    @Published private(set) var publicIPState: NetworkValueState = .unavailable("Not available")

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private let locationManager = CLLocationManager()
    private let addressSource: NetworkAddressSource
    private let publicIPClient: PublicIPClient
    private var lastPublicIPFetch: Date?
    private let publicIPMinimumInterval: TimeInterval = 30

    var canScanWiFi: Bool { currentConnection != "LAN" }

    var currentSSID: String {
        Self.displaySSID(
            connection: currentConnection,
            ssid: CWWiFiClient.shared().interface()?.ssid()
        )
    }

    var networkDisplayName: String {
        Self.networkDisplayName(
            connection: currentConnection,
            interfaceName: activeInterfaceName,
            ssid: CWWiFiClient.shared().interface()?.ssid()
        )
    }

    override convenience init() {
        self.init(addressSource: SystemNetworkAddressSource(), publicIPClient: IpifyPublicIPClient())
    }

    init(addressSource: NetworkAddressSource, publicIPClient: PublicIPClient, startMonitoring: Bool = true) {
        self.addressSource = addressSource
        self.publicIPClient = publicIPClient
        super.init()
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined { locationManager.requestWhenInUseAuthorization() }
        if startMonitoring { self.startMonitoring() }
        refreshNetworkDetails(forcePublicIP: true)
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connection = Self.connectionState(
                statusIsSatisfied: path.status == .satisfied,
                usesWiredEthernet: path.usesInterfaceType(.wiredEthernet),
                usesWiFi: path.usesInterfaceType(.wifi))
            DispatchQueue.main.async {
                self?.currentConnection = connection
                let preferredInterfaceName = path.availableInterfaces.first {
                    $0.type == .wiredEthernet && connection == "LAN"
                }?.name ?? path.availableInterfaces.first {
                    $0.type == .wifi && connection == "WIFI"
                }?.name
                self?.activeInterfaceName = preferredInterfaceName
                self?.refreshNetworkDetails(
                    forcePublicIP: false,
                    preferredInterfaceName: preferredInterfaceName
                )
            }
        }
        monitor.start(queue: queue)
    }

    static func connectionState(statusIsSatisfied: Bool, usesWiredEthernet: Bool, usesWiFi: Bool) -> String {
        guard statusIsSatisfied else { return "OFF" }
        if usesWiredEthernet { return "LAN" }
        if usesWiFi { return "WIFI" }
        return "OTHER"
    }

    static func networkDisplayName(
        connection: String,
        interfaceName: String?,
        ssid: String?
    ) -> String {
        switch connection {
        case "LAN":
            return interfaceName.map { "Ethernet (\($0))" } ?? "Ethernet"
        case "WIFI":
            if let ssid, !ssid.isEmpty {
                return ssid
            }
            return "Wi-Fi"
        case "OTHER":
            return interfaceName ?? "Other Network"
        default:
            return "Offline"
        }
    }

    static func displaySSID(connection: String, ssid: String?) -> String {
        guard connection == "WIFI",
              let ssid = ssid?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ssid.isEmpty else { return "" }
        return ssid
    }

    static func selectIPv4(
        from snapshots: [NetworkInterfaceSnapshot],
        preferredInterfaceName: String?
    ) -> String? {
        if let preferredInterfaceName,
           let preferred = snapshots.first(where: {
               $0.name == preferredInterfaceName && $0.isActive
           }) {
            return preferred.ipv4
        }
        return snapshots.first(where: { $0.isActive })?.ipv4 ?? snapshots.first?.ipv4
    }

    static func isUsableIPv4Interface(name: String, ipv4: String) -> Bool {
        !name.hasPrefix("lo") && !ipv4.hasPrefix("127.")
    }

    static func validPublicIPAddress(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              IPv4Address(trimmed) != nil || IPv6Address(trimmed) != nil else {
            return nil
        }
        return trimmed
    }

    func refreshNetworkDetails(
        forcePublicIP: Bool = true,
        preferredInterfaceName: String? = nil
    ) {
        let snapshots = addressSource.interfaceSnapshots()
        let localIPv4 = Self.selectIPv4(
            from: snapshots,
            preferredInterfaceName: preferredInterfaceName
        )
        localIPv4State = localIPv4.map { .available($0) } ?? .unavailable("Not available")
        let dns = addressSource.dnsServers()
        dnsServersState = dns.isEmpty
            ? .unavailable("Not available")
            : .available(dns.joined(separator: ", "))
        let now = Date()
        let shouldFetchPublicIP: Bool
        if forcePublicIP || lastPublicIPFetch == nil {
            shouldFetchPublicIP = true
        } else if let lastPublicIPFetch {
            shouldFetchPublicIP = now.timeIntervalSince(lastPublicIPFetch) >= publicIPMinimumInterval
        } else {
            shouldFetchPublicIP = false
        }
        if shouldFetchPublicIP {
            lastPublicIPFetch = now
            publicIPState = .loading
            publicIPClient.fetch { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let value): self?.publicIPState = .available(value)
                    case .failure(let error): self?.publicIPState = .unavailable(error.localizedDescription)
                    }
                }
            }
        }
    }

    func scanForNetworks() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = self.fetchAvailableNetwork()
            DispatchQueue.main.async {
                if case .success(let networks) = result {
                    self.availableNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }
                } else {
                    self.availableNetworks = []
                }
            }
        }
    }

    func fetchAvailableNetwork() -> Result<Set<CWNetwork>, Error> {
        guard canScanWiFi else {
            return .failure(NetworkManagerError.wiredConnectionActive)
        }
        guard let interface = CWWiFiClient.shared().interface() else {
            return .failure(NetworkManagerError.wifiInterfaceUnavailable)
        }
        do {
            let visible = try interface.scanForNetworks(withName: nil).filter {
                !($0.ssid ?? "").isEmpty
            }
            var unique: [String: CWNetwork] = [:]
            for network in visible {
                guard let ssid = network.ssid else { continue }
                if let existing = unique[ssid] {
                    if network.rssiValue > existing.rssiValue {
                        unique[ssid] = network
                    }
                } else {
                    unique[ssid] = network
                }
            }
            return .success(Set(unique.values))
        } catch { return .failure(error) }
    }

    func isKnownNetwork(ssid: String) -> Bool {
        guard let interface = CWWiFiClient.shared().interface(),
              let config = interface.configuration() else {
            return false
        }
        return config.networkProfiles
            .compactMap { $0 as? CWNetworkProfile }
            .contains { $0.ssid == ssid }
    }

    func connectWIFI(ssid: String, password: String?) -> Result<Bool, Error> {
        switch fetchAvailableNetwork() {
        case .failure(let error): return .failure(error)
        case .success(let networks):
            guard let target = networks.first(where: { $0.ssid == ssid }) else {
                return .failure(
                    NSError(
                        domain: "NetworkManager",
                        code: 404,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Specified Wi-Fi network not found"
                        ]
                    )
                )
            }
            guard let interface = CWWiFiClient.shared().interface() else {
                return .failure(NetworkManagerError.wifiInterfaceUnavailable)
            }
            do {
                try interface.associate(to: target, password: password)
                return .success(true)
            } catch {
                return .failure(error)
            }
        }
    }
}

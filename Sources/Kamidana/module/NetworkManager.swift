import Combine
import CoreLocation
import CoreWLAN
import Foundation
import Network

class NetworkManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // Mark with @Published for real-time monitoring in UI
    @Published var currentConnection: String = "OFF"
    @Published var availableNetworks: [CWNetwork] = []

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // Location manager to request authorization required for fetching Wi-Fi SSID
    private let locationManager = CLLocationManager()

    override init() {
        super.init()

        // Request location permission (required to retrieve Wi-Fi SSID)
        locationManager.delegate = self
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        startMonitoring()
    }

    // Start network monitoring
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

        // Start the network path monitor
        monitor.start(queue: queue)
    }

    /// Scan for nearby available Wi-Fi networks and store them in an array
    func scanForNetworks() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = self?.fetchAvailableNetwork()
            DispatchQueue.main.async {
                if case .success(let networks) = result {
                    // Sort by signal strength (descending RSSI value) and store
                    self?.availableNetworks = networks.sorted { $0.rssiValue > $1.rssiValue }
                } else {
                    self?.availableNetworks = []
                }
            }
        }
    }

    /// Scan and fetch available Wi-Fi networks in the vicinity
    func fetchAvailableNetwork() -> Result<Set<CWNetwork>, Error> {
        let client = CWWiFiClient.shared()

        // Obtain the Wi-Fi interface
        guard let interface = client.interface() else {
            let error = NSError(
                domain: "NetworkManager", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Wi-Fi interface not found"])
            return .failure(error)
        }

        do {
            // Perform scan
            let allNetworks = try interface.scanForNetworks(withName: nil)

            // 1. Exclude hidden networks with empty SSID (nil or "")
            let publicNetworks = allNetworks.filter { network in
                guard let ssid = network.ssid, !ssid.isEmpty else {
                    return false
                }
                return true
            }

            // 2. Deduplicate networks with the same SSID (keep the one with the strongest signal, e.g. in mesh Wi-Fi setups)
            var uniqueNetworks = [String: CWNetwork]()
            for network in publicNetworks {
                guard let ssid = network.ssid else { continue }

                if let existing = uniqueNetworks[ssid] {
                    // RSSI (signal strength) is negative (e.g. -50 dBm vs -80 dBm); values closer to 0 indicate stronger signal
                    if network.rssiValue > existing.rssiValue {
                        uniqueNetworks[ssid] = network
                    }
                } else {
                    uniqueNetworks[ssid] = network
                }
            }

            return .success(Set(uniqueNetworks.values))
        } catch {
            // Return error if scanning fails or permissions are missing
            return .failure(error)
        }
    }

    /// Determine whether the specified SSID is a known network previously connected to
    func isKnownNetwork(ssid: String) -> Bool {
        guard let interface = CWWiFiClient.shared().interface(),
              let config = interface.configuration() else {
            return false
        }
        
        let profiles = config.networkProfiles
        for p in profiles {
            if let profile = p as? CWNetworkProfile, profile.ssid == ssid {
                return true
            }
        }
        return false
    }

    /// Connect to Wi-Fi. Pass nil if no password is required (known network or open Wi-Fi)
    func connectWIFI(ssid: String, password: String?) -> Result<Bool, Error> {
        // 1. Fetch available networks list
        let result = fetchAvailableNetwork()

        switch result {
        case .success(let networks):
            // 2. Find matching network with specified SSID from Set<CWNetwork>
            guard let targetNetwork = networks.first(where: { $0.ssid == ssid }) else {
                let error = NSError(
                    domain: "NetworkManager", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Specified Wi-Fi network not found"])
                return .failure(error)
            }

            // 3. Prepare Wi-Fi interface for connection
            let client = CWWiFiClient.shared()
            guard let interface = client.interface() else {
                let error = NSError(
                    domain: "NetworkManager", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Wi-Fi interface not found"])
                return .failure(error)
            }

            do {
                // 4. Attempt association to target network
                try interface.associate(to: targetNetwork, password: password)
                return .success(true)
            } catch {
                // Handle errors such as invalid password
                return .failure(error)
            }

        case .failure(let error):
            // Handle scan failure
            return .failure(error)
        }
    }

}

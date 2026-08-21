import Foundation
import Network

// Structure representing a device discovered via LocalSend
struct LocalSendDevice: Identifiable, Equatable {
    let id = UUID()
    let ip: String
    let alias: String
    let deviceModel: String
    let deviceType: String
    let fingerprint: String
    let port: Int
}

class LocalSendManager: ObservableObject {
    @Published var discoveredDevices: [LocalSendDevice] = []
    
    private var listener: NWListener?
    private var broadcastConnection: NWConnection?
    
    private let localSendPort: NWEndpoint.Port = 53317
    
    // Local device information
    private let myAlias = "Kamidana (Mac)"
    private let myFingerprint = UUID().uuidString
    
    init() {
        startListener()
    }
    
    deinit {
        listener?.cancel()
        broadcastConnection?.cancel()
    }
    
    /// Send an announcement (UDP broadcast) to discover LocalSend devices on the local network
    func scanNetwork() {
        print("[LocalSend] Scanning network for devices...")
        discoveredDevices.removeAll()
        
        let endpoint = NWEndpoint.hostPort(host: "255.255.255.255", port: localSendPort)
        let parameters = NWParameters.udp
        // Allow broadcast
        parameters.allowLocalEndpointReuse = true
        
        broadcastConnection = NWConnection(to: endpoint, using: parameters)
        
        broadcastConnection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            if case .ready = state {
                self.sendAnnounce()
            }
        }
        
        broadcastConnection?.start(queue: .global(qos: .background))
    }
    
    private func sendAnnounce() {
        let payload: [String: Any] = [
            "alias": myAlias,
            "version": "2.0",
            "deviceModel": "macOS",
            "deviceType": "desktop",
            "fingerprint": myFingerprint,
            "port": Int(localSendPort.rawValue),
            "protocol": "https",
            "download": true,
            "announce": true
        ]
        
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        broadcastConnection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("[LocalSend] Failed to send broadcast: \(error)")
            } else {
                print("[LocalSend] Announce sent.")
            }
        }))
    }
    
    /// UDP listener for receiving responses and announcements from other LocalSend devices
    private func startListener() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            
            listener = try NWListener(using: parameters, on: localSendPort)
            
            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.handleIncomingConnection(newConnection)
            }
            
            listener?.start(queue: .global(qos: .background))
            print("[LocalSend] UDP Listener started on port \(localSendPort)")
        } catch {
            print("[LocalSend] Failed to start UDP listener: \(error)")
        }
    }
    
    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .background))
        
        connection.receiveMessage { [weak self] (data, context, isComplete, error) in
            guard let self = self, let data = data else { return }
            
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let alias = dict["alias"] as? String,
               let fingerprint = dict["fingerprint"] as? String,
               fingerprint != self.myFingerprint { // Ignore own broadcast
                
                // Extract IP address
                var ipAddress = "Unknown"
                if case .hostPort(let host, _) = connection.endpoint {
                    // Convert host (NWEndpoint.Host) to string
                    ipAddress = String(describing: host)
                    // Clean up interface scope identifier (e.g. "%en0" in IPv6)
                    if let interfaceIndex = ipAddress.firstIndex(of: "%") {
                        ipAddress = String(ipAddress[..<interfaceIndex])
                    }
                }
                
                let model = dict["deviceModel"] as? String ?? "Unknown Model"
                let type = dict["deviceType"] as? String ?? "mobile"
                let port = dict["port"] as? Int ?? 53317
                
                let newDevice = LocalSendDevice(ip: ipAddress, alias: alias, deviceModel: model, deviceType: type, fingerprint: fingerprint, port: port)
                
                DispatchQueue.main.async {
                    // Check for duplicates
                    if !self.discoveredDevices.contains(where: { $0.fingerprint == newDevice.fingerprint }) {
                        self.discoveredDevices.append(newDevice)
                        print("[LocalSend] Device Found: \(alias) (\(model))")
                    }
                }
            }
            connection.cancel()
        }
    }
}

import Foundation
import CoreWLAN

let client = CWWiFiClient.shared()
guard let interface = client.interface() else { exit(1) }

if let preferred = interface.preferredNetworks() {
    print("Preferred Networks Count: \(preferred.count)")
    for p in preferred.prefix(5) {
        print("- \(p.ssid ?? "Unknown")")
    }
}

import Foundation
import CoreWLAN

let client = CWWiFiClient.shared()
guard let interface = client.interface() else { exit(1) }
// Just testing compilation, not actually running
let _: Void = {
    let network: CWNetwork! = nil
    do {
        try interface.associate(to: network, password: nil)
    } catch {}
}()
print("Compiles fine!")

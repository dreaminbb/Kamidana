import AppKit
import Combine
import Foundation
import IOBluetooth

// Common device struct for easy handling in UI and other components
public struct BluetoothDeviceInfo: Identifiable {
    public let id: String  // Use MAC address as ID
    public let name: String
    public let isConnected: Bool
    public let isPaired: Bool
}

class BluetoothManager: NSObject, ObservableObject {

    // Mark with @Published so the UI can monitor the state
    @Published var isBluetoothOn = false
    @Published var pairedDevices: [BluetoothDeviceInfo] = []

    // Timer for periodically updating the state
    private var timer: AnyCancellable?

    override init() {
        super.init()
        checkBluetoothState()
        refreshPairedDevices()

        // Update connection state of paired devices every 3 seconds
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkBluetoothState()
                self?.refreshPairedDevices()
            }
    }

    /// Check Bluetooth power state
    func checkBluetoothState() {
        if IOBluetoothHostController.default() != nil {
            isBluetoothOn = true
        } else {
            isBluetoothOn = false
        }
    }

    /// Fetch and update all paired devices on the Mac
    public func refreshPairedDevices() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            self.pairedDevices = []
            return
        }

        // Update on main thread (sort connected devices to the top)
        DispatchQueue.main.async {
            self.pairedDevices = devices.map { device in
                BluetoothDeviceInfo(
                    id: device.addressString ?? UUID().uuidString,
                    name: device.name ?? "Unknown Device",
                    isConnected: device.isConnected(),
                    isPaired: device.isPaired()
                )
            }
            .sorted { $0.isConnected && !$1.isConnected }
        }
    }

    /// Open macOS Bluetooth settings
    public func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }
}

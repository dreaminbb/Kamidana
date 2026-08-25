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
        isBluetoothOn = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
    }

    /// Fetch and update Bluetooth devices known to the Mac.
    public func refreshPairedDevices() {
        let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let recentDevices = IOBluetoothDevice.recentDevices(20) as? [IOBluetoothDevice] ?? []
        let deviceInfos = Self.deviceInfos(from: pairedDevices + recentDevices)

        DispatchQueue.main.async {
            self.pairedDevices = deviceInfos
        }
    }

    static func deviceInfos(from devices: [IOBluetoothDevice]) -> [BluetoothDeviceInfo] {
        var devicesByID: [String: BluetoothDeviceInfo] = [:]

        for device in devices {
            let id = device.addressString ?? device.name ?? UUID().uuidString
            let info = BluetoothDeviceInfo(
                id: id,
                name: device.name ?? "Unknown Device",
                isConnected: device.isConnected(),
                isPaired: device.isPaired()
            )

            if let existing = devicesByID[id] {
                devicesByID[id] = preferredDeviceInfo(existing, info)
            } else {
                devicesByID[id] = info
            }
        }

        return devicesByID.values.sorted { lhs, rhs in
            if lhs.isConnected != rhs.isConnected { return lhs.isConnected }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func preferredDeviceInfo(
        _ lhs: BluetoothDeviceInfo,
        _ rhs: BluetoothDeviceInfo
    ) -> BluetoothDeviceInfo {
        if lhs.isConnected != rhs.isConnected { return lhs.isConnected ? lhs : rhs }
        if lhs.isPaired != rhs.isPaired { return lhs.isPaired ? lhs : rhs }
        return lhs
    }

    /// Open macOS Bluetooth settings
    @discardableResult
    public func openBluetoothSettings() -> Bool {
        Self.openBluetoothSettings()
    }

    @discardableResult
    static func openBluetoothSettings(
        openURL: (URL) -> Bool = { NSWorkspace.shared.open($0) },
        openSettingsApp: () -> Bool = { BluetoothManager.openSystemSettings() }
    ) -> Bool {
        for url in bluetoothSettingsURLs where openURL(url) {
            return true
        }
        return openSettingsApp()
    }

    static let bluetoothSettingsURLs: [URL] = [
        URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings"),
        URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth"),
    ].compactMap { $0 }

    private static func openSystemSettings() -> Bool {
        guard let settingsURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.systempreferences"
        ) else {
            return false
        }

        NSWorkspace.shared.openApplication(
            at: settingsURL,
            configuration: NSWorkspace.OpenConfiguration()
        )
        return true
    }
}

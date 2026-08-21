import XCTest

@testable import KamidanaApp

final class BluetoothWidgetTests: XCTestCase {
    func testConnectedDeviceFormatValuesIncludeOnlyConnectedDevices() {
        let devices = [
            BluetoothDeviceInfo(id: "1", name: "Headphones", isConnected: true, isPaired: true),
            BluetoothDeviceInfo(id: "2", name: "Trackpad", isConnected: false, isPaired: true),
            BluetoothDeviceInfo(id: "3", name: "Keyboard", isConnected: true, isPaired: true),
        ]

        let values = BluetoothWidget.connectedDeviceFormatValues(devices)
        let connectedDevices = BluetoothWidget.connectedDevices(devices)

        XCTAssertEqual(values.deviceCount, "2")
        XCTAssertEqual(values.deviceName, "Headphones")
        XCTAssertEqual(connectedDevices.map(\.name), ["Headphones", "Keyboard"])
    }

    func testConnectedDeviceNameIsEmptyWhenNoDevicesAreConnected() {
        let devices = [
            BluetoothDeviceInfo(id: "1", name: "Trackpad", isConnected: false, isPaired: true)
        ]

        let values = BluetoothWidget.connectedDeviceFormatValues(devices)

        XCTAssertEqual(values.deviceCount, "0")
        XCTAssertEqual(values.deviceName, "")
    }
}

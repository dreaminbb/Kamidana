import XCTest

@testable import Kamidana

final class BluetoothWidgetTests: XCTestCase {
    func testConnectedDeviceFormatValuesIncludeOnlyConnectedDevices() {
        let devices = [
            BluetoothDeviceInfo(id: "1", name: "Headphones", isConnected: true, isPaired: true),
            BluetoothDeviceInfo(id: "2", name: "Trackpad", isConnected: false, isPaired: true),
            BluetoothDeviceInfo(id: "3", name: "Keyboard", isConnected: true, isPaired: true),
        ]

        let values = BluetoothWidget.connectedDeviceFormatValues(devices)

        XCTAssertEqual(values.deviceCount, "2")
        XCTAssertEqual(values.deviceName, "Headphones")
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

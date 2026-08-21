import Combine
import XCTest

@testable import KamidanaApp

private final class StubNetworkAddressSource: NetworkAddressSource {
    let snapshots: [NetworkInterfaceSnapshot]
    let dns: [String]

    init(snapshots: [NetworkInterfaceSnapshot], dns: [String]) {
        self.snapshots = snapshots
        self.dns = dns
    }

    func interfaceSnapshots() -> [NetworkInterfaceSnapshot] { snapshots }
    func dnsServers() -> [String] { dns }
}

private final class StubPublicIPClient: PublicIPClient {
    var requestCount = 0
    let result: Result<String, Error>

    init(result: Result<String, Error>) { self.result = result }

    func fetch(completion: @escaping (Result<String, Error>) -> Void) {
        requestCount += 1
        completion(result)
    }
}

final class NetworkManagerTests: XCTestCase {
    func testWiredConnectionTakesPriorityOverWiFi() {
        XCTAssertEqual(
            NetworkManager.connectionState(
                statusIsSatisfied: true,
                usesWiredEthernet: true,
                usesWiFi: true
            ),
            "LAN"
        )
        XCTAssertEqual(
            NetworkManager.connectionState(
                statusIsSatisfied: true,
                usesWiredEthernet: false,
                usesWiFi: true
            ),
            "WIFI"
        )
        XCTAssertEqual(
            NetworkManager.connectionState(
                statusIsSatisfied: false,
                usesWiredEthernet: true,
                usesWiFi: true
            ),
            "OFF"
        )
    }

  func testNetworkDisplayNameUsesConnectionSpecificNames() {
        XCTAssertEqual(
            NetworkManager.networkDisplayName(
                connection: "LAN",
                interfaceName: "en5",
                ssid: nil
            ),
            "Ethernet (en5)"
        )
        XCTAssertEqual(
            NetworkManager.networkDisplayName(
                connection: "WIFI",
                interfaceName: "en0",
                ssid: "Kamidana"
            ),
            "Kamidana"
        )
        XCTAssertEqual(
            NetworkManager.networkDisplayName(
                connection: "OFF",
                interfaceName: nil,
                ssid: nil
            ),
            "Offline"
        )
  }

  func testSSIDIsOnlyAvailableForWiFiConnections() {
    XCTAssertEqual(NetworkManager.displaySSID(connection: "WIFI", ssid: "Office Wi-Fi"), "Office Wi-Fi")
    XCTAssertEqual(NetworkManager.displaySSID(connection: "LAN", ssid: "Office Wi-Fi"), "")
    XCTAssertEqual(NetworkManager.displaySSID(connection: "OFF", ssid: "Office Wi-Fi"), "")
    XCTAssertEqual(NetworkManager.displaySSID(connection: "WIFI", ssid: "   "), "")
  }

    func testWiFiScanIsDisabledForWiredConnection() {
        let source = StubNetworkAddressSource(snapshots: [], dns: [])
        let client = StubPublicIPClient(result: .failure(NetworkManagerError.invalidPublicIPResponse))
        let manager = NetworkManager(addressSource: source, publicIPClient: client, startMonitoring: false)
        manager.currentConnection = "LAN"

        XCTAssertFalse(manager.canScanWiFi)
        guard case .failure(let error) = manager.fetchAvailableNetwork() else {
            return XCTFail("Expected wired scan to fail before accessing CoreWLAN")
        }
        XCTAssertEqual(error as? NetworkManagerError, .wiredConnectionActive)
    }

    func testWiFiScanIsAllowedWhenConnectionIsOff() {
        let source = StubNetworkAddressSource(snapshots: [], dns: [])
        let client = StubPublicIPClient(result: .failure(NetworkManagerError.invalidPublicIPResponse))
        let manager = NetworkManager(addressSource: source, publicIPClient: client, startMonitoring: false)
        manager.currentConnection = "OFF"

        XCTAssertTrue(manager.canScanWiFi)
    }

    func testNetworkDetailsPreferActiveInterfaceAndPublishStates() {
        let source = StubNetworkAddressSource(
            snapshots: [
                NetworkInterfaceSnapshot(name: "en1", ipv4: "192.168.1.9", isActive: false),
                NetworkInterfaceSnapshot(name: "en0", ipv4: "10.0.0.4", isActive: true)
            ],
            dns: ["1.1.1.1", "8.8.8.8"])
        let client = StubPublicIPClient(result: .success("203.0.113.5"))
        let manager = NetworkManager(addressSource: source, publicIPClient: client, startMonitoring: false)

        XCTAssertEqual(manager.localIPv4State, .available("10.0.0.4"))
        XCTAssertEqual(manager.dnsServersState, .available("1.1.1.1, 8.8.8.8"))
        let publicIPExpectation = expectation(description: "Public IP state becomes available")
        var cancellable: AnyCancellable?
        cancellable = manager.$publicIPState.sink { state in
            if state == .available("203.0.113.5") {
                publicIPExpectation.fulfill()
                cancellable?.cancel()
            }
        }
        wait(for: [publicIPExpectation], timeout: 1.0)
        XCTAssertEqual(manager.publicIPState, .available("203.0.113.5"))
        XCTAssertEqual(client.requestCount, 1)

        manager.refreshNetworkDetails(forcePublicIP: false)
        XCTAssertEqual(client.requestCount, 1)
    }

    func testPreferredInterfaceIsSelectedBeforeOtherActiveInterfaces() {
        let snapshots = [
            NetworkInterfaceSnapshot(name: "en0", ipv4: "192.168.1.4", isActive: true),
            NetworkInterfaceSnapshot(name: "en5", ipv4: "10.0.0.4", isActive: true)
        ]

        XCTAssertEqual(
            NetworkManager.selectIPv4(from: snapshots, preferredInterfaceName: "en5"),
            "10.0.0.4"
        )
        XCTAssertEqual(
            NetworkManager.selectIPv4(from: snapshots, preferredInterfaceName: "en9"),
            "192.168.1.4"
        )
    }

    func testLoopbackInterfacesAreExcludedFromLocalIPv4Candidates() {
        XCTAssertFalse(
            NetworkManager.isUsableIPv4Interface(name: "lo0", ipv4: "127.0.0.1")
        )
        XCTAssertFalse(
            NetworkManager.isUsableIPv4Interface(name: "en0", ipv4: "127.0.0.1")
        )
        XCTAssertTrue(
            NetworkManager.isUsableIPv4Interface(name: "en0", ipv4: "192.168.1.4")
        )
    }

    func testPublicIPAddressValidationAcceptsIPv4AndIPv6Only() {
        XCTAssertEqual(
            NetworkManager.validPublicIPAddress(" 203.0.113.5\n"),
            "203.0.113.5"
        )
        XCTAssertEqual(
            NetworkManager.validPublicIPAddress("2001:db8::5"),
            "2001:db8::5"
        )
        XCTAssertNil(NetworkManager.validPublicIPAddress("not-an-ip-address"))
        XCTAssertNil(NetworkManager.validPublicIPAddress(""))
    }
}

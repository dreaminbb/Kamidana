import XCTest

@testable import KamidanaApp

final class LaunchAtLoginManagerTests: XCTestCase {
    func testRegistersWhenEnabledConfigurationNeedsRegistration() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        let manager = LaunchAtLoginManager(service: service)

        manager.synchronize(isEnabled: true)

        XCTAssertEqual(service.actions, [.register])
    }

    func testRegistersWhenMainApplicationServiceIsNotFound() {
        let service = FakeLaunchAtLoginService(status: .notFound)
        let manager = LaunchAtLoginManager(service: service)

        manager.synchronize(isEnabled: true)

        XCTAssertEqual(service.actions, [.register])
    }

    func testUnregistersWhenDisabledConfigurationHasRegisteredService() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let manager = LaunchAtLoginManager(service: service)

        manager.synchronize(isEnabled: false)

        XCTAssertEqual(service.actions, [.unregister])
    }

    func testDoesNotRepeatRegistrationOrApprovalRequests() {
        let enabledService = FakeLaunchAtLoginService(status: .enabled)
        LaunchAtLoginManager(service: enabledService).synchronize(isEnabled: true)

        let pendingApprovalService = FakeLaunchAtLoginService(status: .requiresApproval)
        LaunchAtLoginManager(service: pendingApprovalService).synchronize(isEnabled: true)

        XCTAssertTrue(enabledService.actions.isEmpty)
        XCTAssertTrue(pendingApprovalService.actions.isEmpty)
    }

    func testDoesNotUnregisterAnUnregisteredService() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)

        LaunchAtLoginManager(service: service).synchronize(isEnabled: false)

        XCTAssertTrue(service.actions.isEmpty)
    }
}

private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    enum Action: Equatable {
        case register
        case unregister
    }

    var status: LaunchAtLoginServiceStatus
    private(set) var actions: [Action] = []

    init(status: LaunchAtLoginServiceStatus) {
        self.status = status
    }

    func register() throws {
        actions.append(.register)
    }

    func unregister() throws {
        actions.append(.unregister)
    }
}

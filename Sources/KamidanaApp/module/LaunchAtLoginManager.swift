import ServiceManagement

enum LaunchAtLoginServiceStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown
}

protocol LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus { get }

    func register() throws
    func unregister() throws
}

struct SystemLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginServiceStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unknown
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class LaunchAtLoginManager {
    private let service: any LaunchAtLoginServicing

    init(service: any LaunchAtLoginServicing = SystemLaunchAtLoginService()) {
        self.service = service
    }

    func synchronize(isEnabled: Bool) {
        let action: String
        let operation: () throws -> Void

        switch (isEnabled, service.status) {
        case (true, .notRegistered), (true, .notFound):
            action = "register launch at login"
            operation = service.register
        case (false, .enabled), (false, .requiresApproval):
            action = "unregister launch at login"
            operation = service.unregister
        default:
            return
        }

        do {
            try operation()
        } catch {
            DebugRichConsole.printLaunchAtLoginFailure(action: action, error: error)
        }
    }
}

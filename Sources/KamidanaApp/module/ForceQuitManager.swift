import AppKit
import Combine

enum ForceQuitRequestResult {
    case requested
    case alreadyTerminated
    case failed
}

/// Retains the application instance rather than resolving a potentially reused PID at execution time.
protocol ForceQuitApplication: AnyObject {
    var processIdentifier: pid_t { get }
    var bundleIdentifier: String? { get }
    var localizedName: String? { get }
    var launchDate: Date? { get }
    var isRegularApplication: Bool { get }
    var isTerminated: Bool { get }
    func requestForceQuit() async -> ForceQuitRequestResult
}

extension NSRunningApplication: ForceQuitApplication {
    var isRegularApplication: Bool { activationPolicy == .regular }

    func requestForceQuit() async -> ForceQuitRequestResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard !self.isTerminated else {
                    continuation.resume(returning: .alreadyTerminated)
                    return
                }
                if self.forceTerminate() {
                    continuation.resume(returning: .requested)
                } else {
                    continuation.resume(returning: self.isTerminated ? .alreadyTerminated : .failed)
                }
            }
        }
    }
}

enum ForceQuitWorkspaceEvent {
    case activated(ForceQuitApplication)
    case terminated(ForceQuitApplication)
}

@MainActor
protocol ForceQuitWorkspace {
    var frontmostApplication: ForceQuitApplication? { get }
    /// Events must be delivered on the main thread.
    var events: AnyPublisher<ForceQuitWorkspaceEvent, Never> { get }
}

@MainActor
private struct SystemForceQuitWorkspace: ForceQuitWorkspace {
    var frontmostApplication: ForceQuitApplication? { NSWorkspace.shared.frontmostApplication }

    var events: AnyPublisher<ForceQuitWorkspaceEvent, Never> {
        let center = NSWorkspace.shared.notificationCenter
        let activations = center.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .map { ForceQuitWorkspaceEvent.activated($0) }
        let terminations = center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .compactMap { $0.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication }
            .map { ForceQuitWorkspaceEvent.terminated($0) }
        return activations.merge(with: terminations)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

enum ForceQuitFeedback: Equatable {
    case noTarget
    case alreadyTerminated(String)
    case requested(String)
    case failed(String)

    var message: String {
        switch self {
        case .noTarget: return "No active external application."
        case .alreadyTerminated(let name): return "\(name) has already quit."
        case .requested(let name): return "Force quit requested for \(name)."
        case .failed(let name): return "Could not force quit \(name). Try again."
        }
    }

    var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

@MainActor
final class ForceQuitManager: ObservableObject {
    static let shared = ForceQuitManager(
        workspace: SystemForceQuitWorkspace(),
        ownProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
        ownBundleIdentifier: Bundle.main.bundleIdentifier
    )

    @Published private(set) var target: ForceQuitApplication?
    @Published private(set) var feedback: ForceQuitFeedback?
    @Published private(set) var isRequesting = false

    private let workspace: ForceQuitWorkspace
    private let ownProcessIdentifier: pid_t
    private let ownBundleIdentifier: String?
    private var observation: AnyCancellable?
    private var selectionRevision = 0

    init(
        workspace: ForceQuitWorkspace,
        ownProcessIdentifier: pid_t,
        ownBundleIdentifier: String?
    ) {
        self.workspace = workspace
        self.ownProcessIdentifier = ownProcessIdentifier
        self.ownBundleIdentifier = ownBundleIdentifier
    }

    /// Call during application launch, before Kamidana activates or any action popup opens.
    func startMonitoring() {
        guard observation == nil else { return }
        observation = workspace.events.sink { [weak self] event in
            self?.handle(event)
        }
        select(workspace.frontmostApplication)
    }

    var targetName: String? {
        target.map { $0.localizedName ?? $0.bundleIdentifier ?? "Application (\($0.processIdentifier))" }
    }

    var canForceQuit: Bool {
        guard let target else { return false }
        return !isRequesting && isEligible(target) && !target.isTerminated
    }

    var statusMessage: String {
        if isRequesting { return "Requesting force quit…" }
        if let feedback { return feedback.message }
        if let targetName { return "Target: \(targetName)" }
        return ForceQuitFeedback.noTarget.message
    }

    func forceQuitCurrentApplication() async {
        guard !isRequesting else { return }
        startMonitoring()
        // Reconcile a foreground change whose workspace notification has not arrived yet.
        select(workspace.frontmostApplication)
        guard let application = target, isEligible(application), let name = targetName else {
            feedback = .noTarget
            return
        }
        guard !application.isTerminated else {
            target = nil
            feedback = .alreadyTerminated(name)
            return
        }

        let revision = selectionRevision
        isRequesting = true
        feedback = nil
        let result = await application.requestForceQuit()
        isRequesting = false
        // An old request must not replace feedback for a newly activated application.
        guard revision == selectionRevision else { return }
        switch result {
        case .requested:
            feedback = .requested(name)
        case .alreadyTerminated:
            target = nil
            feedback = .alreadyTerminated(name)
        case .failed:
            feedback = .failed(name)
        }
    }

    private func isSelf(_ application: ForceQuitApplication) -> Bool {
        application.processIdentifier == ownProcessIdentifier
            || (ownBundleIdentifier != nil && application.bundleIdentifier == ownBundleIdentifier)
    }

    private func isEligible(_ application: ForceQuitApplication) -> Bool {
        !isSelf(application) && application.processIdentifier > 0 && application.isRegularApplication
    }

    private func select(_ application: ForceQuitApplication?) {
        // Kamidana activation, including its popups, must preserve the external target.
        guard let application, !isSelf(application) else { return }
        guard isEligible(application), !application.isTerminated else {
            if target != nil {
                selectionRevision += 1
                target = nil
                feedback = nil
            }
            return
        }
        guard !matchesTarget(application) else { return }
        selectionRevision += 1
        target = application
        feedback = nil
    }

    private func matchesTarget(_ application: ForceQuitApplication) -> Bool {
        guard let target else { return false }
        return target.processIdentifier == application.processIdentifier
            && target.launchDate == application.launchDate
    }

    private func handle(_ event: ForceQuitWorkspaceEvent) {
        switch event {
        case .activated(let application):
            select(application)
        case .terminated(let application):
            guard matchesTarget(application), let name = targetName else { return }
            target = nil
            feedback = .alreadyTerminated(name)
        }
    }
}

import AppKit
import SwiftUI

final class WidgetHoverTracker {
    static let transitionDelay: TimeInterval = Theme.Motion.standard.hoverSettleDelay

    private(set) var isHovered = false
    private var pendingID: UUID?

    func update(
        _ hovering: Bool,
        delay: TimeInterval = WidgetHoverTracker.transitionDelay,
        apply: @escaping (Bool) -> Void
    ) {
        guard hovering != isHovered else {
            pendingID = nil
            return
        }

        let transitionID = UUID()
        pendingID = transitionID
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.pendingID == transitionID else { return }
            self.pendingID = nil
            guard self.isHovered != hovering else { return }
            self.isHovered = hovering
            apply(hovering)
        }
    }

    func reset() {
        pendingID = nil
        isHovered = false
    }
}

final class WidgetInteractionController: ObservableObject {
    @Published private(set) var isPresented = false

    private var anchorHovered = false
    private var popupHovered = false
    private var pendingAnchorID: UUID?
    private var pendingPopupID: UUID?
    private var pendingDismissalID: UUID?

    var presentation: Binding<Bool> {
        Binding(
            get: { [weak self] in self?.isPresented ?? false },
            set: { [weak self] value in self?.setPresented(value) }
        )
    }

    @discardableResult
    func activate(_ activation: KamidanaActivation) -> Bool {
        guard activation == .click else { return false }
        cancelPendingTransitions()
        anchorHovered = false
        popupHovered = false
        isPresented.toggle()
        return isPresented
    }

    func updateAnchorHover(
        _ hovering: Bool,
        activation: KamidanaActivation,
        settleDelay: TimeInterval,
        dismissDelay: TimeInterval
    ) {
        guard activation == .hover else { return }
        schedule(
            hovering,
            isAnchor: true,
            settleDelay: settleDelay,
            dismissDelay: dismissDelay
        )
    }

    func updatePopupHover(
        _ hovering: Bool,
        activation: KamidanaActivation,
        settleDelay: TimeInterval,
        dismissDelay: TimeInterval
    ) {
        guard activation == .hover else { return }
        schedule(
            hovering,
            isAnchor: false,
            settleDelay: settleDelay,
            dismissDelay: dismissDelay
        )
    }

    func setPresented(_ presented: Bool) {
        cancelPendingTransitions()
        isPresented = presented
        if !presented {
            anchorHovered = false
            popupHovered = false
        }
    }

    func reset() {
        setPresented(false)
    }

    private func schedule(
        _ hovering: Bool,
        isAnchor: Bool,
        settleDelay: TimeInterval,
        dismissDelay: TimeInterval
    ) {
        let transitionID = UUID()
        if isAnchor {
            pendingAnchorID = transitionID
        } else {
            pendingPopupID = transitionID
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in
            guard let self,
                  (isAnchor ? self.pendingAnchorID : self.pendingPopupID) == transitionID
            else { return }
            if isAnchor {
                self.pendingAnchorID = nil
            } else {
                self.pendingPopupID = nil
            }
            if isAnchor {
                self.anchorHovered = hovering
            } else {
                self.popupHovered = hovering
            }

            if self.anchorHovered || self.popupHovered {
                self.pendingDismissalID = nil
                self.isPresented = true
                return
            }

            let dismissalID = UUID()
            self.pendingDismissalID = dismissalID
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay) { [weak self] in
                guard let self,
                      self.pendingDismissalID == dismissalID,
                      !self.anchorHovered,
                      !self.popupHovered
                else { return }
                self.pendingDismissalID = nil
                self.isPresented = false
            }
        }
    }

    private func cancelPendingTransitions() {
        pendingAnchorID = nil
        pendingPopupID = nil
        pendingDismissalID = nil
    }
}

struct WidgetActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(WidgetButtonStyle())
    }
}

private struct WidgetInteractionModifier<PopupContent: View>: ViewModifier {
    @ObservedObject var controller: WidgetInteractionController
    let activation: KamidanaActivation
    let popupContent: (Binding<Bool>) -> PopupContent

    @Environment(\.theme) private var theme
    @Environment(\.kamidanaWidgetAnimation) private var animation
    @Environment(\.kamidanaPopupHorizontalAlignment) private var horizontalAlignment
    @Environment(\.popupTheme) private var popupTheme

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                controller.updateAnchorHover(
                    hovering,
                    activation: activation,
                    settleDelay: theme?.motion.hoverSettleDelay
                        ?? Theme.Motion.standard.hoverSettleDelay,
                    dismissDelay: theme?.motion.popupDismissDelay
                        ?? Theme.Motion.standard.popupDismissDelay
                )
            }
            .zIndex(controller.isPresented ? 1_000 : 0)
            .overlay(alignment: horizontalAlignment.swiftUIAlignment) {
                if controller.isPresented {
                    popupContent(controller.presentation)
                        .modifier(KamidanaPopupSurfaceModifier())
                        .offset(y: 40)
                        .transition(popupTransition)
                        .onHover { hovering in
                            controller.updatePopupHover(
                                hovering,
                                activation: activation,
                                settleDelay: popupTheme?.motion.hoverSettleDelay
                                    ?? Theme.Motion.standard.hoverSettleDelay,
                                dismissDelay: popupTheme?.motion.popupDismissDelay
                                    ?? Theme.Motion.standard.popupDismissDelay
                            )
                        }
                        .zIndex(1_000)
                }
            }
            .animation(popupAnimation, value: controller.isPresented)
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didActivateApplicationNotification
                )
            ) { notification in
                guard
                    let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication,
                    application.bundleIdentifier != Bundle.main.bundleIdentifier
                else { return }
                controller.reset()
            }
    }

    private var popupAnimation: Animation? {
        guard animation == .dynamic else { return nil }
        return (popupTheme?.motion.expand ?? Theme.Motion.standard.expand).resolvedAnimation()
    }

    private var popupTransition: AnyTransition {
        guard animation == .dynamic else { return .identity }
        return .move(edge: .top).combined(with: .opacity)
    }
}

extension View {
    func widgetInteraction<PopupContent: View>(
        controller: WidgetInteractionController,
        activation: KamidanaActivation,
        @ViewBuilder popup: @escaping (Binding<Bool>) -> PopupContent
    ) -> some View {
        modifier(
            WidgetInteractionModifier(
                controller: controller,
                activation: activation,
                popupContent: popup
            )
        )
    }
}

enum WidgetInteractionState: Equatable {
    case idle
    case hover
    case pressed
}

enum WidgetSeverity: Equatable {
    case normal
    case warning
    case critical
}

private struct WidgetSeverityEnvironmentKey: EnvironmentKey {
    static let defaultValue = WidgetSeverity.normal
}

extension EnvironmentValues {
    var widgetSeverity: WidgetSeverity {
        get { self[WidgetSeverityEnvironmentKey.self] }
        set { self[WidgetSeverityEnvironmentKey.self] = newValue }
    }
}

extension View {
    func widgetSeverity(_ severity: WidgetSeverity) -> some View {
        environment(\.widgetSeverity, severity)
    }
}

extension KamidanaAnimation {
    func resolvedAnimation() -> Animation? {
        switch preset {
        case .none:
            return nil
        case .linear:
            return .linear(
                duration: durationSeconds
                    ?? Theme.Motion.standard.colorChange.durationSeconds
                    ?? 0.2
            )
        case .easeInOut:
            return .easeInOut(
                duration: durationSeconds
                    ?? Theme.Motion.standard.colorChange.durationSeconds
                    ?? 0.2
            )
        case .spring:
            return .spring(
                response: response ?? Theme.Motion.standard.expand.response ?? 0.3,
                dampingFraction: damping ?? Theme.Motion.standard.expand.damping ?? 0.85,
                blendDuration: blendDuration
                    ?? Theme.Motion.standard.expand.blendDuration
                    ?? 0
            )
        }
    }
}

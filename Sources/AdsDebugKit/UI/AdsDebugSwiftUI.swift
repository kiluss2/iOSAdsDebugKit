#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

public enum AdsDebugSwiftUIBridge {
    public static func show() {
        AdsDebugWindowManager.shared.show()
    }

    public static func hide() {
        AdsDebugWindowManager.shared.hide()
    }

    public static func toggle() {
        AdsDebugWindowManager.shared.toggle()
    }
}

@available(iOS 13.0, *)
public extension View {
    func adsDebugConsoleLifecycle(enabled: Bool = true) -> some View {
        onAppear {
            guard enabled else { return }
            AdTelemetry.refreshDebugServices()
        }
    }

    func adsDebugComboUnlock(
        enabled: Bool = true,
        onUnlock: (() -> Void)? = nil
    ) -> some View {
        modifier(AdsDebugComboUnlockModifier(enabled: enabled, onUnlock: onUnlock))
    }
}

@available(iOS 13.0, *)
private struct AdsDebugComboUnlockModifier: ViewModifier {
    let enabled: Bool
    let onUnlock: (() -> Void)?

    func body(content: Content) -> some View {
        if enabled {
            content.overlay(AdsDebugComboUnlockHost(onUnlock: onUnlock))
        } else {
            content
        }
    }
}

@available(iOS 13.0, *)
private struct AdsDebugComboUnlockHost: UIViewRepresentable {
    let onUnlock: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onUnlock: onUnlock)
    }

    func makeUIView(context: Context) -> ComboUnlockHostView {
        let view = ComboUnlockHostView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.accessibilityIdentifier = "AdsDebugComboUnlockHost"
        view.coordinator = context.coordinator
        context.coordinator.install(on: view)
        return view
    }

    func updateUIView(_ uiView: ComboUnlockHostView, context: Context) {
        context.coordinator.onUnlock = onUnlock
        uiView.coordinator = context.coordinator
        context.coordinator.install(on: uiView)
    }

    final class Coordinator {
        fileprivate var onUnlock: (() -> Void)?
        private let helper = DebugComboGestureHelper()
        private weak var installedView: UIView?

        init(onUnlock: (() -> Void)?) {
            self.onUnlock = onUnlock
        }

        func install(on view: UIView) {
            guard installedView !== view else { return }
            helper.cleanup()
            installedView = view
            helper.setup(on: view) { [weak self] in
                if let onUnlock = self?.onUnlock {
                    onUnlock()
                } else {
                    AdsDebugWindowManager.shared.show()
                }
            }
            view.gestureRecognizers?.forEach {
                $0.cancelsTouchesInView = false
                $0.delaysTouchesBegan = false
                $0.delaysTouchesEnded = false
            }
        }

        deinit {
            helper.cleanup()
        }
    }

    final class ComboUnlockHostView: UIView {
        weak var coordinator: Coordinator?
    }
}
#endif

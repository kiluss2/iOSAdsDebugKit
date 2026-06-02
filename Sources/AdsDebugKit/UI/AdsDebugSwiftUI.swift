#if canImport(SwiftUI)
import SwiftUI

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
}
#endif

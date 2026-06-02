//
//  AdsDebugWindowManager.swift
//  AdsDebugKit
//
//  Created by Son Le on 2025.
//

import UIKit

/// Top-level window to present Ads Debug UI as a full-height sheet
public final class AdsDebugWindowManager: NSObject {
    public static let shared = AdsDebugWindowManager()

    private var debugWindow: UIWindow?
    private weak var hostVC: UIViewController?

    private override init() {}

    /// Show full-height sheet
    public func show() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.show() }
            return
        }
        guard debugWindow == nil else { return }

        // Pick the current foreground scene (for multi-window safety)
        let win = UIWindow(frame: UIScreen.main.bounds)
        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            win.windowScene = scene
        }

        win.accessibilityIdentifier = "AdsDebugWindow"
        win.windowLevel = .alert + 2
        win.backgroundColor = .clear

        // Host VC used only to present the sheet
        let host = UIViewController()
        host.view.backgroundColor = .clear
        win.rootViewController = host
        win.makeKeyAndVisible()

        self.debugWindow = win
        self.hostVC = host

        DispatchQueue.main.async {
            let debugVC = AdsDebugVC()
            debugVC.modalPresentationStyle = .fullScreen
            debugVC.presentationController?.delegate = self
            host.present(debugVC, animated: true, completion: nil)
        }
    }

    /// Hide (dismiss presented sheet first if needed)
    public func hide() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.hide() }
            return
        }
        if let presented = hostVC?.presentedViewController {
            presented.dismiss(animated: true) { [weak self] in
                self?.tearDownWindow()
            }
        } else {
            tearDownWindow()
        }
    }
    
    /// Toggle debug window (show if hidden, hide if visible)
    public func toggle() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.toggle() }
            return
        }
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    private func tearDownWindow() {
        debugWindow?.isHidden = true
        debugWindow = nil
        hostVC = nil
    }

    public var isVisible: Bool {
        return debugWindow != nil && debugWindow?.isHidden == false
    }
}

extension AdsDebugWindowManager: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // User swiped down / interactive dismiss → cleanup window
        tearDownWindow()
    }
}

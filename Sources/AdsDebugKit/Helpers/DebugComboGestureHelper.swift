//
//  DebugComboGestureHelper.swift
//  AdsDebugKit
//
//  Created on 2025.
//

import UIKit
import ObjectiveC

public enum DebugComboGestureStep: Equatable {
    case swipeDown
    case swipeUp
    case swipeLeft
    case swipeRight
    case tap(count: Int)

    public static let defaultSequence: [DebugComboGestureStep] = [
        .swipeDown,
        .tap(count: 2),
        .swipeUp
    ]
}

/// Helper class to handle debug combo gesture: swipe down → double tap → swipe up
public final class DebugComboGestureHelper: NSObject {
    // MARK: - Properties
    
    private weak var targetView: UIView?
    private var sequence = DebugComboGestureStep.defaultSequence
    private var progressIndex = 0
    private var comboTimer: Timer?
    private var comboTimeout: TimeInterval = 3.0 // Must complete combo within this window.
    
    // Gesture recognizers
    private var panGesture: UIPanGestureRecognizer?
    private var tapGestures: [UITapGestureRecognizer] = []
    
    // Thresholds for swipe detection
    private let velocityThreshold: CGFloat = 500
    private let translationThreshold: CGFloat = 50
    
    // Completion callback
    private var onComboCompleted: (() -> Void)?
    
    // Associated object key for storing helper in unlockView
    private static var helperKey: UInt8 = 0
    
    // MARK: - Public Methods

    /// Setup debug combo gesture on the given view using the default sequence and action.
    /// The default action enables debug mode and shows the AdsDebugKit panel.
    public func setup(on unlockView: UIView) {
        setup(on: unlockView, sequence: DebugComboGestureStep.defaultSequence, timeout: 3.0)
    }
    
    /// Setup debug combo gesture on the given view using the default sequence:
    /// swipe down → double tap → swipe up.
    /// Helper is automatically stored in view's associated object.
    /// - Parameters:
    ///   - unlockView: The view to attach gestures to
    ///   - completion: Callback when combo is completed successfully
    public func setup(on unlockView: UIView, completion: @escaping () -> Void) {
        setup(on: unlockView, sequence: DebugComboGestureStep.defaultSequence, timeout: 3.0, completion: completion)
    }

    /// Setup debug combo gesture on the given view with a custom unlock sequence and default action.
    /// The default action enables debug mode and shows the AdsDebugKit panel.
    public func setup(
        on unlockView: UIView,
        sequence: [DebugComboGestureStep],
        timeout: TimeInterval = 3.0
    ) {
        setup(on: unlockView, sequence: sequence, timeout: timeout) {
            AdsDebugWindowManager.shared.show()
        }
    }

    /// Setup debug combo gesture on the given view with a custom unlock sequence.
    /// Helper is automatically stored in view's associated object
    /// - Parameters:
    ///   - unlockView: The view to attach gestures to
    ///   - sequence: Ordered unlock steps. Empty sequences are ignored.
    ///   - timeout: Maximum time to complete the whole sequence.
    ///   - completion: Callback when combo is completed successfully
    public func setup(
        on unlockView: UIView,
        sequence: [DebugComboGestureStep],
        timeout: TimeInterval = 3.0,
        completion: @escaping () -> Void
    ) {
        // Cleanup previous setup if any
        if let existing = objc_getAssociatedObject(unlockView, &Self.helperKey) as? DebugComboGestureHelper {
            existing.cleanup()
        }

        let normalizedSequence = sequence.map(\.normalized)
        guard !normalizedSequence.isEmpty else { return }
        
        // Store self in unlockView's associated object to prevent deallocation
        objc_setAssociatedObject(unlockView, &Self.helperKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        targetView = unlockView
        self.sequence = normalizedSequence
        comboTimeout = timeout
        onComboCompleted = completion
        
        // Enable user interaction
        unlockView.isUserInteractionEnabled = true

        if normalizedSequence.contains(where: { $0.isSwipe }) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            unlockView.addGestureRecognizer(pan)
            panGesture = pan
        }

        let tapCounts = Array(Set(normalizedSequence.compactMap(\.tapCount))).sorted()
        for tapCount in tapCounts {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.numberOfTapsRequired = tapCount
            tap.delegate = self
            unlockView.addGestureRecognizer(tap)
            tapGestures.append(tap)
        }

        for lowerTap in tapGestures {
            for higherTap in tapGestures where higherTap.numberOfTapsRequired > lowerTap.numberOfTapsRequired {
                lowerTap.require(toFail: higherTap)
            }
        }
    }
    
    /// Cleanup and remove all gestures
    public func cleanup() {
        comboTimer?.invalidate()
        comboTimer = nil
        
        if let pan = panGesture {
            targetView?.removeGestureRecognizer(pan)
        }
        for tapGesture in tapGestures {
            targetView?.removeGestureRecognizer(tapGesture)
        }
        
        // Remove from associated object
        if let unlockView = targetView {
            objc_setAssociatedObject(unlockView, &Self.helperKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        
        panGesture = nil
        tapGestures = []
        targetView = nil
        onComboCompleted = nil
        resetCombo()
    }
    
    // MARK: - Private Methods
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let targetView = targetView else { return }
        
        let translation = gesture.translation(in: targetView)
        let velocity = gesture.velocity(in: targetView)
        
        switch gesture.state {
        case .ended:
            if let step = swipeStep(translation: translation, velocity: velocity) {
                handle(step)
            }
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        handle(.tap(count: gesture.numberOfTapsRequired))
    }

    private func swipeStep(translation: CGPoint, velocity: CGPoint) -> DebugComboGestureStep? {
        if abs(velocity.y) >= abs(velocity.x),
           abs(velocity.y) > velocityThreshold,
           abs(translation.y) > translationThreshold {
            return velocity.y > 0 && translation.y > 0 ? .swipeDown : .swipeUp
        }

        if abs(velocity.x) > velocityThreshold,
           abs(translation.x) > translationThreshold {
            return velocity.x > 0 && translation.x > 0 ? .swipeRight : .swipeLeft
        }

        return nil
    }

    private func handle(_ step: DebugComboGestureStep) {
        guard !sequence.isEmpty else { return }

        if step == sequence[progressIndex] {
            if progressIndex == 0 {
                startComboTimer()
            }
            progressIndex += 1

            if progressIndex == sequence.count {
                completeCombo()
            }
            return
        }

        if step == sequence[0] {
            progressIndex = 1
            startComboTimer()

            if sequence.count == 1 {
                completeCombo()
            }
        } else {
            resetCombo()
        }
    }

    private func startComboTimer() {
        comboTimer?.invalidate()
        comboTimer = Timer.scheduledTimer(withTimeInterval: comboTimeout, repeats: false) { [weak self] _ in
            self?.resetCombo()
        }
    }
    
    private func resetCombo() {
        progressIndex = 0
        comboTimer?.invalidate()
        comboTimer = nil
    }
    
    private func completeCombo() {
        resetCombo()
        AdTelemetry.setDebugEnabled(true)
        AdToast.show("Debug mode enabled")
        onComboCompleted?()
    }
    
    deinit {
        cleanup()
    }
}

private extension DebugComboGestureStep {
    var normalized: DebugComboGestureStep {
        switch self {
        case .tap(let count):
            return .tap(count: max(1, count))
        case .swipeDown, .swipeUp, .swipeLeft, .swipeRight:
            return self
        }
    }

    var tapCount: Int? {
        guard case .tap(let count) = self else { return nil }
        return count
    }

    var isSwipe: Bool {
        switch self {
        case .swipeDown, .swipeUp, .swipeLeft, .swipeRight:
            return true
        case .tap:
            return false
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension DebugComboGestureHelper: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

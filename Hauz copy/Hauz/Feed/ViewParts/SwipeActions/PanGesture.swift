import SwiftUI

struct PanGestureValue {
    var translation: CGSize = .zero
    var velocity: CGSize = .zero
}

struct PanGesture: UIGestureRecognizerRepresentable {
    var onBegan: () -> ()
    var onChange: (PanGestureValue) -> ()
    var onEnded: (PanGestureValue) -> ()
    
    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }
    
    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        gesture.addTarget(context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        context.coordinator.onBegan = onBegan
        context.coordinator.onChange = onChange
        context.coordinator.onEnded = onEnded
        return gesture
    }
    
    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Update coordinator with new closures if needed
        context.coordinator.onBegan = onBegan
        context.coordinator.onChange = onChange
        context.coordinator.onEnded = onEnded
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onBegan: (() -> ())?
        var onChange: ((PanGestureValue) -> ())?
        var onEnded: ((PanGestureValue) -> ())?
        
        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view).toSize
            let velocity = recognizer.velocity(in: recognizer.view).toSize
            
            let gestureValue = PanGestureValue(translation: translation, velocity: velocity)
            
            switch recognizer.state {
            case .began:
                onBegan?()
            case .changed:
                onChange?(gestureValue)
            case .ended, .cancelled, .failed:
                onEnded?(gestureValue)
            default:
                break
            }
        }
        
        // Allow both horizontal swipe and vertical scroll to work together
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            
            let velocity = panGesture.velocity(in: panGesture.view)
            
            // Favor horizontal swipes for the swipe action
            // But be more lenient than before to make it feel natural
            return abs(velocity.x) > abs(velocity.y) * 0.7
        }
        
        // Allow simultaneous recognition with scroll view
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Allow simultaneous recognition with scroll views
            return otherGestureRecognizer is UIPanGestureRecognizer
        }
    }
}

extension CGPoint {
    var toSize: CGSize {
        return CGSize(width: x, height: y)
    }
}

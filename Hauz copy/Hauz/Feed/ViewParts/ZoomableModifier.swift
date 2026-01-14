import SwiftUI

/// Pinch-to-zoom for a view (intentionally minimal + easy to remove).
///
/// Design goals:
/// - Localized: can be removed by deleting this file and removing `.zoomable(...)` call sites.
/// - Low interference: uses a magnification gesture (2 fingers) so single-finger swipe gestures keep working.
/// - Predictable: clamps scale and supports double-tap to reset.
struct ZoomableModifier: ViewModifier {
    let enabled: Bool
    let minScale: CGFloat
    let maxScale: CGFloat
    let doubleTapZoomScale: CGFloat
    
    @State private var baseScale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    
    private var effectiveScale: CGFloat {
        let s = baseScale * gestureScale
        return min(max(s, minScale), maxScale)
    }
    
    func body(content: Content) -> some View {
        if !enabled {
            content
        } else {
            content
                .scaleEffect(effectiveScale)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    MagnificationGesture()
                        .updating($gestureScale) { value, state, _ in
                            state = value
                        }
                        .onEnded { value in
                            let proposed = baseScale * value
                            baseScale = min(max(proposed, minScale), maxScale)
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                baseScale = (abs(baseScale - minScale) < 0.01) ? min(doubleTapZoomScale, maxScale) : minScale
                            }
                        }
                )
                // Keep the zoom animation subtle and only when scale changes.
                .animation(.spring(response: 0.28, dampingFraction: 0.9), value: baseScale)
        }
    }
}

extension View {
    /// Enable pinch-to-zoom + double-tap reset for this view.
    func zoomable(
        enabled: Bool = true,
        minScale: CGFloat = 1,
        maxScale: CGFloat = 4,
        doubleTapZoomScale: CGFloat = 2
    ) -> some View {
        modifier(
            ZoomableModifier(
                enabled: enabled,
                minScale: minScale,
                maxScale: maxScale,
                doubleTapZoomScale: doubleTapZoomScale
            )
        )
    }
}


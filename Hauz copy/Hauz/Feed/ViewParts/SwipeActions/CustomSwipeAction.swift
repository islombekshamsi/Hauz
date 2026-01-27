import SwiftUI
import UIKit

struct Action: Identifiable {
    var id = UUID().uuidString
    var symbolImage: String
    var tint: Color
    var background: Color
    
    var font: Font = .title3
    var size: CGSize = .init(width: 80, height: 80)
    var shape: some Shape = .circle
    var action: (inout Bool) -> ()
}

@resultBuilder
struct ActionBuilder {
    static func buildBlock(_ components: Action...) -> [Action] {
        return components
    }
}

struct ActionConfig {
    var leadingPadding: CGFloat = 0
    var trailingPadding: CGFloat = 10
    var spacing: CGFloat = 10
    var occupiesFullWidth: Bool = true
    /// Space between card and action bubble when revealed
    var detachedGap: CGFloat = 8
    /// Circular delete button diameter
    var deleteDiameter: CGFloat = 58
    /// Reveal threshold (fraction of cell width)
    var revealThreshold: CGFloat = 0.3
    /// Full reveal distance (fraction of cell width)
    var fullReveal: CGFloat = 0.65
    /// Allow rubber-band past full reveal (fraction of cell width)
    var maxReveal: CGFloat = 0.75
}

extension View {
    @ViewBuilder
    func swipeActions(config: ActionConfig = .init(), @ActionBuilder actions: () -> [Action]) -> some View {
        self
            .modifier(CustomSwipeActionModifier(config: config, actions: actions()))
    }
}

@MainActor
@Observable
class SwipeActionSharedData {
    static let shared = SwipeActionSharedData()
    
    var activeSwipeAction: String?
}

fileprivate struct CustomSwipeActionModifier: ViewModifier {
    var config: ActionConfig
    var actions: [Action]
    
    @State private var resetPositionTrigger: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var lastStoredOffsetX: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var didTriggerHaptic: Bool = false
    @State private var contentWidth: CGFloat = 0
    
    @State private var currentScrollOffset: CGFloat = 0
    @State private var storedScrollOffset: CGFloat?
    var sharedData = SwipeActionSharedData.shared
    @State private var currentID: String = UUID().uuidString
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Background action buttons - positioned independently
            DeleteButtonView(
                revealWidth: max(0, min(config.deleteDiameter * 1.6, -offsetX - config.trailingPadding - config.detachedGap)),
                action: actions.last,
                diameter: config.deleteDiameter,
                trailingPadding: config.trailingPadding,
                resetPositionTrigger: $resetPositionTrigger
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Main content on top
            content
                .offset(x: offsetX)
                .offset(x: bounceOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    if offsetX != 0 {
                        reset()
                    }
                }
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            gestureDidChange(translation: value.translation)
                        }
                        .onEnded { value in
                            gestureDidEnded(translation: value.translation, velocity: value.velocity)
                        }
                )
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { contentWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newValue in
                        contentWidth = newValue
                    }
            }
        )
        .onChange(of: resetPositionTrigger) { oldValue, newValue in
            reset()
        }
        .onChange(of: sharedData.activeSwipeAction) { oldValue, newValue in
            if newValue != currentID && offsetX != 0 {
                reset()
            }
        }
        .clipped()
    }
    
    private struct DeleteButtonView: View {
        let revealWidth: CGFloat
        let action: Action?
        let diameter: CGFloat
        let trailingPadding: CGFloat
        @Binding var resetPositionTrigger: Bool
        
        var body: some View {
            if let action = action {
                let buttonWidth = max(2, revealWidth)
                let iconOpacity = iconOpacityFor(width: buttonWidth)
                
                Button {
                    action.action(&resetPositionTrigger)
                } label: {
                    ZStack(alignment: .trailing) {
                        // Expanding capsule - starts from right edge
                        Capsule()
                            .fill(action.background)
                            .frame(width: buttonWidth, height: diameter)
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 2)
                        
                        // Icon - appears as button expands
                        Image(systemName: action.symbolImage)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(iconOpacity)
                            .frame(width: diameter, height: diameter)
                    }
                    // CRITICAL: This makes it expand from right edge
                    .frame(width: buttonWidth, height: diameter, alignment: .trailing)
                }
                .frame(width: buttonWidth, height: diameter, alignment: .trailing)
                .padding(.trailing, trailingPadding)
                .buttonStyle(.plain)
                .pressStyle(scale: 0.95)
                .allowsHitTesting(buttonWidth >= diameter * 0.6) // Allow taps once visible
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: buttonWidth)
            }
        }
        
        private func iconOpacityFor(width: CGFloat) -> CGFloat {
            // Show icon when button is mostly expanded
            if width < 40 { return 0 }
            let clamped = min(max((width - 40) / (diameter - 40), 0), 1)
            return clamped
        }
    }
    
    private func gestureDidChange(translation: CGSize) {
        let fullReveal = maxRevealDistance
        let desired = translation.width + lastStoredOffsetX
        
        // Limit swipe to left only
        if desired < -fullReveal {
            // Rubber band effect when swiping past full reveal
            let extra = abs(desired) - fullReveal
            let damped = extra * 0.25
            offsetX = -(fullReveal + damped)
            progress = 1.0
        } else if desired <= 0 {
            // Normal swipe
            offsetX = desired
            progress = min(max(abs(desired) / fullReveal, 0), 1)
        } else {
            // Swiping right - reset
            offsetX = 0
            progress = 0
        }
        
        // Calculate bounce offset for rubber band effect
        bounceOffset = min(translation.width - (offsetX - lastStoredOffsetX), 0) / 8
        
        // Haptic feedback when button is fully revealed
        if progress >= 0.95 && !didTriggerHaptic {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            didTriggerHaptic = true
        }
        
#if DEBUG
        if Int(translation.width) % 10 == 0 {
            print("🧹 Swipe debug: offsetX=\(offsetX), progress=\(String(format: "%.2f", progress)), buttonWidth=\(String(format: "%.1f", config.deleteDiameter * debugEaseOutProgress(progress)))")
        }
#endif
    }
    
    private func gestureDidEnded(translation: CGSize, velocity: CGSize) {
        let endTarget = velocity.width + offsetX
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            // If swiped enough or has sufficient velocity, reveal fully
            if abs(endTarget) > (maxRevealDistance * config.revealThreshold) || velocity.width < -300 {
                offsetX = -maxRevealDistance
                bounceOffset = 0
                progress = 1.0
            } else {
                // Snap back to closed
                reset()
            }
        }
        lastStoredOffsetX = offsetX
    }
    
    private func reset() {
        withAnimation(.snappy(duration: 0.3, extraBounce: 0)) {
            offsetX = 0
            lastStoredOffsetX = 0
            progress = 0
            bounceOffset = 0
            didTriggerHaptic = false
        }
        
        storedScrollOffset = nil
    }
    
    var maxRevealDistance: CGFloat {
        max(0, contentWidth * min(max(config.fullReveal, 0.1), 0.9))
    }
    
    private func debugEaseOutProgress(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return 1 - pow(1 - clamped, 2.2)
    }
}

private extension View {
    func pressStyle(scale: CGFloat) -> some View {
        self.buttonStyle(PressScaleButtonStyle(scale: scale))
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    SwiftUIView()
}

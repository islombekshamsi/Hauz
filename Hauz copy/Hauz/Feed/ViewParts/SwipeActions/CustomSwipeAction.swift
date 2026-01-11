import SwiftUI

struct Action: Identifiable{
    var id = UUID().uuidString
    var symbolImage: String
    var tint: Color
    var background: Color
    
    var font: Font = .title3
    var size: CGSize = .init(width: 80 ,height: 80)
    var shape: some Shape = .circle
    var action: (inout Bool) -> ()
}


@resultBuilder
struct ActionBuilder{
    static func buildBlock(_ components: Action...)-> [Action] {
        return components
    }
}

struct ActionConfig{
    var leadingPadding: CGFloat = 0
    var trailingPadding: CGFloat = 10
    var spacing: CGFloat = 10
    var occupiesFullWidth: Bool = true
}

extension View{
    
    @ViewBuilder
    func swipeActions(config: ActionConfig = .init(), @ActionBuilder actions: () -> [Action])->some View{
        self
            .modifier(CustomSwipeActionModifier(config: config, actions: actions()))
    }
}

@MainActor
@Observable
class SwipeActionSharedData{
    static let shared = SwipeActionSharedData()
    
    var activeSwipeAction: String?
}

fileprivate struct CustomSwipeActionModifier: ViewModifier{
    var config: ActionConfig
    var actions: [Action]
    
    @State private var resetPositionTrigger: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var lastStoredOffsetX: CGFloat = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var deleteButtonExpansion: CGFloat = 0 // For horizontal expansion
    @State private var shouldAutoDelete: Bool = false
    
    @State private var currentScrollOffset: CGFloat = 0
    @State private var storedScrollOffset: CGFloat?
    var sharedData = SwipeActionSharedData.shared
    @State private var currentID: String = UUID().uuidString
    func body(content: Content) -> some View{
        ZStack(alignment: .trailing) {
            // Background action buttons
            ActionsView()
            
            // Main content on top
            content
                .offset(x: offsetX)
                .offset(x: bounceOffset)
                .gesture(
                    PanGesture(onBegan:{
                        gestureDidBegan()
                    }, onChange: { value in
                        gestureDidChange(translation: value.translation)
                    }, onEnded:{ value in
                        gestureDidEnded(translation: value.translation, velocity: value.velocity)
                    })
                )
        }
        .onChange(of: resetPositionTrigger){oldValue, newValue in
            reset()
        }
        .onGeometryChange(for: CGFloat.self){
            $0.frame(in: .scrollView).minY
        } action: {newValue in
            if let storedScrollOffset, storedScrollOffset != newValue{
                reset()
            }
            
        }
        .onChange(of: sharedData.activeSwipeAction){oldValue, newValue in
            if newValue != currentID && offsetX != 0{
                reset()
            }
            
        }
    }
    
    @ViewBuilder
    func ActionsView() -> some View{
        HStack(spacing: config.spacing) {
            ForEach(actions.indices, id: \.self) { index in
                let action = actions[index]
                let isLastAction = index == actions.count - 1
                
                if isLastAction {
                    // 🔥 DELETE BUTTON - Expands horizontally like iMessage
                    let buttonWidth = action.size.width + (deleteButtonExpansion * 180)
                    let cornerRadius = action.size.height / 2
                    
                    Button {
                        // Tap to trigger auto-expand + delete
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            deleteButtonExpansion = 1.0
                            offsetX = -maxOffsetWidth * 1.5
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            action.action(&resetPositionTrigger)
                        }
                    } label: {
                        ZStack {
                            // Background that expands
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(action.background)
                                .frame(width: buttonWidth, height: action.size.height)
                            
                            // Icon stays on the right
                            HStack(spacing: -10) {
                                Spacer()
                                Image(systemName: action.symbolImage)
                                    .font(action.font)
                                    .foregroundStyle(action.tint)
                                    .frame(width: action.size.width)
                            }
                            .frame(width: buttonWidth, height: action.size.height)
                        }
                    }
                    .frame(height: action.size.height)
                } else {
                    // Regular button (non-expanding)
                    Button {
                        action.action(&resetPositionTrigger)
                    } label: {
                        Image(systemName: action.symbolImage)
                            .font(action.font)
                            .foregroundStyle(action.tint)
                            .frame(width: action.size.width, height: action.size.height)
                            .background(action.background, in: action.shape)
                    }
                }
            }
        }
        .padding(.trailing, config.trailingPadding)
        .padding(.leading, config.leadingPadding)
    }
    
    private func gestureDidBegan(){
        storedScrollOffset = lastStoredOffsetX
        sharedData.activeSwipeAction = currentID
    }
    
    private func gestureDidChange(translation: CGSize){
        offsetX = min(max(translation.width + lastStoredOffsetX, -maxOffsetWidth * 1.5), 0)
        progress = -offsetX/maxOffsetWidth
        
        // Calculate delete button horizontal expansion (iMessage style)
        // Start expanding earlier for smoother feel
        let expansionThreshold = maxOffsetWidth * 0.75
        if -offsetX > expansionThreshold {
            // Smooth expansion curve
            let extraDistance = -offsetX - expansionThreshold
            let expansionRange = maxOffsetWidth * 0.5
            deleteButtonExpansion = min(extraDistance / expansionRange, 1.0)
            // Trigger auto-delete at 85% expansion
            shouldAutoDelete = deleteButtonExpansion > 0.85
        } else {
            deleteButtonExpansion = 0
            shouldAutoDelete = false
        }
        
        bounceOffset = min(translation.width - (offsetX - lastStoredOffsetX), 0) / 10
    }
    
    private func gestureDidEnded(translation: CGSize, velocity: CGSize){
        let endTarget = velocity.width + offsetX
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)){
            // Auto-delete if expanded far enough (iMessage style)
            if shouldAutoDelete || deleteButtonExpansion > 0.85 {
                // Trigger delete action
                if actions.count > 0 {
                    // Full expansion animation before deleting
                    deleteButtonExpansion = 1.0
                    offsetX = -maxOffsetWidth * 1.5
                    
                    // Execute delete action after smooth animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        actions[actions.count - 1].action(&resetPositionTrigger)
                    }
                }
            }
            // Standard swipe behavior - snap to revealed position
            else if -endTarget > (maxOffsetWidth * 0.5) {
                offsetX = -maxOffsetWidth
                bounceOffset = 0
                progress = 1
                deleteButtonExpansion = 0
            } else {
                // Snap back to closed
                reset()
            }
        }
        lastStoredOffsetX = offsetX
    }
    
    private func reset(){
        withAnimation(.snappy(duration: 0.3, extraBounce: 0)){
            offsetX = 0
            lastStoredOffsetX = 0
            progress = 0
            bounceOffset = 0
            deleteButtonExpansion = 0
            shouldAutoDelete = false
        }
        
        storedScrollOffset = nil
    }
    
    var maxOffsetWidth: CGFloat{
        let totalActionSize: CGFloat = actions.reduce(.zero){partialResult, action in
            partialResult + action.size.width
        }
        
        let spacing = config.spacing * CGFloat(actions.count - 1)
        
        return totalActionSize + spacing + config.leadingPadding + config.trailingPadding
    }
}

#Preview{
    SwiftUIView()
}

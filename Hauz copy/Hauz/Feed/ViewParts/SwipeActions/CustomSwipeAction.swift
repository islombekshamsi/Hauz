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
            // Other buttons (blue share, etc.)
            ForEach(actions.indices.dropLast(), id: \.self){ index in
                let action = actions[index]
                
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
            
            // Expanding delete button (last button) - grows horizontally
            if actions.count > 0 {
                let lastAction = actions[actions.count - 1]
                let buttonWidth = lastAction.size.width + (deleteButtonExpansion * 200)
                
                Button {
                    // Auto-expand delete animation
                    withAnimation(.easeOut(duration: 0.3)) {
                        deleteButtonExpansion = 1.0
                        offsetX = -maxOffsetWidth * 1.5
                    }
                    // Then trigger delete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        lastAction.action(&resetPositionTrigger)
                    }
                } label: {
                    HStack(spacing: 0) {
                        // Expanding left side
                        if deleteButtonExpansion > 0 {
                            Spacer()
                                .frame(width: deleteButtonExpansion * 200)
                        }
                        // Icon stays centered in original button area
                        Image(systemName: lastAction.symbolImage)
                            .font(lastAction.font)
                            .foregroundStyle(lastAction.tint)
                            .frame(width: lastAction.size.width, height: lastAction.size.height)
                    }
                    .frame(width: buttonWidth, height: lastAction.size.height)
                    .background(lastAction.background, in: RoundedRectangle(cornerRadius: lastAction.size.height / 2))
                }
                .frame(height: lastAction.size.height)
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
        let expansionThreshold = maxOffsetWidth * 0.85
        if -offsetX > expansionThreshold {
            // Start expanding horizontally when swiped past threshold
            let extraDistance = -offsetX - expansionThreshold
            deleteButtonExpansion = min(extraDistance / (maxOffsetWidth * 0.3), 1.0)
            shouldAutoDelete = deleteButtonExpansion > 0.8
        } else {
            deleteButtonExpansion = 0
            shouldAutoDelete = false
        }
        
        bounceOffset = min(translation.width - (offsetX - lastStoredOffsetX), 0) / 10
    }
    
    private func gestureDidEnded(translation: CGSize, velocity: CGSize){
        let endTarget = velocity.width + offsetX
        
        withAnimation(.snappy(duration: 0.3, extraBounce: 0)){
            // Auto-delete if expanded far enough (iMessage style)
            if shouldAutoDelete || deleteButtonExpansion > 0.8 {
                // Trigger delete action
                if actions.count > 0 {
                    // Full expansion animation before deleting
                    deleteButtonExpansion = 1.0
                    offsetX = -maxOffsetWidth * 1.5
                    
                    // Execute delete action after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        actions[actions.count - 1].action(&resetPositionTrigger)
                    }
                }
            }
            // Standard swipe behavior
            else if -endTarget > (maxOffsetWidth * 0.6) {
                offsetX = -maxOffsetWidth
                bounceOffset = 0
                progress = 1
                deleteButtonExpansion = 0
            } else {
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

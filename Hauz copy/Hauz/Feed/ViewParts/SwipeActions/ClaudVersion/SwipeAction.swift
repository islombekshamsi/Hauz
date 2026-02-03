import SwiftUI

// MARK: - Main Content View
struct SwipeAction: View {
    @State private var items: [SwipeItem] = [
        SwipeItem(id: 1, title: "Item 1", color: .blue),
        SwipeItem(id: 2, title: "Item 2", color: .green),
        SwipeItem(id: 3, title: "Item 3", color: .orange),
        SwipeItem(id: 4, title: "Item 4", color: .purple),
        SwipeItem(id: 5, title: "Item 5", color: .pink)
    ]
    
    @State private var activeSwipeID: Int? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        SwipeableItemView(
                            item: item,
                            isActive: activeSwipeID == item.id,
                            activeSwipeID: $activeSwipeID, // Pass binding for control
                            onSwipeChanged: { isOpen in
                                if isOpen {
                                    activeSwipeID = item.id
                                } else if activeSwipeID == item.id {
                                    activeSwipeID = nil
                                }
                            },
                            onDelete: {
                                deleteItem(item)
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Swipe to Delete")
        }
    }
    
    private func deleteItem(_ item: SwipeItem) {
        // Smooth removal with spring animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
            items.removeAll { $0.id == item.id }
        }
        activeSwipeID = nil
    }
}

// MARK: - Data Model
struct SwipeItem: Identifiable {
    let id: Int
    let title: String
    let color: Color
}

// MARK: - Swipeable Item View
struct SwipeableItemView: View {
    let item: SwipeItem
    let isActive: Bool
    @Binding var activeSwipeID: Int?
    let onSwipeChanged: (Bool) -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting: Bool = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var buttonOpacity: Double = 1.0
    @State private var buttonWidth: CGFloat = 55
    @State private var buttonBrightness: Double = 0
    @State private var itemHeight: CGFloat = 80
    @State private var verticalPadding: CGFloat = 0
    
    private let initialSwipeDistance: CGFloat = 110
    private let autoDeleteThreshold: CGFloat = 220
    private let swipeThreshold: CGFloat = 50
    private let minButtonWidth: CGFloat = 15
    private let buttonHeight: CGFloat = 50
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .trailing) {
                // Background container
                Color.clear
                
                // Delete button - icon only, fully visible, revolutionary!
                deleteButton
                    .frame(width: buttonWidth)
                    .padding(.trailing, 15) // Perfect spacing!
                
                // Main content
                itemContent
                    .offset(x: offset)
                    .frame(height: itemHeight)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                handleDragChanged(gesture, screenWidth: geometry.size.width)
                            }
                            .onEnded { gesture in
                                handleDragEnded(gesture)
                            }
                    )
                    .onChange(of: isActive) { newValue in
                        if !newValue && offset != 0 {
                            closeSwipe()
                        }
                    }
            }
            .frame(height: itemHeight)
        }
        .frame(height: itemHeight)
        .padding(.vertical, verticalPadding)
        .clipped()
    }
    
    // MARK: - Revolutionary Icon-Only Delete Button
    private var deleteButton: some View {
        Button(action: {
            performDelete()
        }) {
            // Centered icon with perfect alignment
            HStack {
                Spacer()
                
                Image(systemName: "trash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .frame(height: buttonHeight)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .brightness(buttonBrightness)
            )
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Item Content
    private var itemContent: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(item.color.gradient)
            .overlay(
                HStack {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Visual indicator for swipe progress
                    if abs(offset) > swipeThreshold {
                        Image(systemName: abs(offset) > autoDeleteThreshold * 0.8 ? "arrow.left.circle.fill" : "arrow.left.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
            )
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(_ gesture: DragGesture.Value, screenWidth: CGFloat) {
        let translation = gesture.translation.width
        
        // Close any other open item when starting to swipe this one
        if translation < 0 && activeSwipeID != item.id && activeSwipeID != nil {
            activeSwipeID = nil
        }
        
        if translation < 0 {
            // Left swipe - reveal delete button
            let rawOffset = translation
            offset = max(rawOffset, -autoDeleteThreshold - 50)
            
            // Calculate revolutionary horizontal expansion
            let swipeDistance = abs(offset)
            let maxWidth = screenWidth
            let expandedWidth = minButtonWidth + (swipeDistance * 0.7)
            
            // Calculate brightness increase
            let brightnessProgress = min(abs(offset) / autoDeleteThreshold, 1.0)
            
            // Smooth animations - fully visible icon that expands
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
                
                // Revolutionary horizontal expansion - icon stays centered!
                buttonWidth = min(expandedWidth, maxWidth)
                
                // Progressive brightness glow
                buttonBrightness = brightnessProgress * 0.15
            }
            
            // Haptic feedback at auto-delete threshold
            if abs(offset) >= autoDeleteThreshold {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
        } else if offset < 0 {
            // Right swipe when already open
            let newOffset = offset + translation
            offset = min(newOffset, 0)
            
            let swipeDistance = abs(offset)
            let expandedWidth = minButtonWidth + (swipeDistance * 0.7)
            let brightnessProgress = min(abs(offset) / autoDeleteThreshold, 1.0)
            
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = min(expandedWidth, screenWidth)
                buttonBrightness = brightnessProgress * 0.15
            }
        }
    }
    
    private func handleDragEnded(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        let velocity = gesture.predictedEndTranslation.width - translation
        
        // Auto-delete if swiped beyond threshold
        if abs(offset) >= autoDeleteThreshold {
            performDelete()
            return
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if abs(offset) > swipeThreshold || velocity < -300 {
                // Snap to open position with more space
                offset = -initialSwipeDistance
                buttonScale = 1.0
                buttonOpacity = 1.0
                buttonWidth = minButtonWidth + (initialSwipeDistance * 0.7)
                buttonBrightness = (initialSwipeDistance / autoDeleteThreshold) * 0.15
                onSwipeChanged(true)
                
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } else {
                // Snap back to closed
                closeSwipe()
            }
        }
    }
    
    // MARK: - Close Swipe
    private func closeSwipe() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            offset = 0
            buttonScale = 1.0
            buttonOpacity = 0
            buttonWidth = minButtonWidth
            buttonBrightness = 0
            onSwipeChanged(false)
        }
    }
    
    // MARK: - Delete Action with Smooth Disappearance
    // MARK: - Delete Action with Smooth Disappearance
    private func performDelete() {
        isDeleting = true
        
        // Strong haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Smooth disappearance animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
            itemHeight = 0
            verticalPadding = -6
            offset = -400
            buttonOpacity = 0
        }
        
        // Delay to allow animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDelete()
        }
    }
}

// MARK: - Preview
#Preview {
    SwipeAction()
}

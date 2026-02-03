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
    let onSwipeChanged: (Bool) -> Void
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting: Bool = false
    @State private var buttonScale: CGFloat = 0.5
    @State private var buttonOpacity: Double = 0
    @State private var itemHeight: CGFloat = 80
    @State private var verticalPadding: CGFloat = 0
    
    private let initialSwipeDistance: CGFloat = 100
    private let autoDeleteThreshold: CGFloat = 200
    private let swipeThreshold: CGFloat = 50
    private let buttonSpacing: CGFloat = 12 // Space between item and button
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Background container
            Color.clear
            
            // Delete button with spacing
            deleteButton
                .offset(x: calculateButtonOffset())
            
            // Main content
            itemContent
                .offset(x: offset)
                .frame(height: itemHeight)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            handleDragChanged(gesture)
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
        .padding(.vertical, verticalPadding)
        .clipped()
    }
    
    // MARK: - Delete Button with Capsule Shape
    private var deleteButton: some View {
        Button(action: {
            performDelete()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Delete")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(buttonScale)
            .opacity(buttonOpacity)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.trailing, buttonSpacing)
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
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Button Offset Calculation with Spacing
    private func calculateButtonOffset() -> CGFloat {
        // Button starts completely off-screen
        let progress = min(abs(offset) / initialSwipeDistance, 1.0)
        
        // Slide in from the right with spacing consideration
        let maxOffset = 100.0 // Start position off-screen
        return maxOffset - (progress * maxOffset)
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        
        if translation < 0 {
            // Left swipe - show delete button
            let rawOffset = translation
            
            // Allow swiping beyond the auto-delete threshold
            offset = max(rawOffset, -autoDeleteThreshold - 50)
            
            // Calculate animation progress for button
            let progress = min(abs(offset) / initialSwipeDistance, 1.0)
            
            // Smooth scale and opacity animation
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 0.5 + (progress * 0.5)
                buttonOpacity = progress
            }
            
            // Check if we've reached auto-delete threshold
            if abs(offset) >= autoDeleteThreshold {
                // Provide haptic feedback at threshold
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            }
            
        } else if offset < 0 {
            // Right swipe when already open - close the button
            let newOffset = offset + translation
            offset = min(newOffset, 0)
            
            let progress = min(abs(offset) / initialSwipeDistance, 1.0)
            
            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.85)) {
                buttonScale = 0.5 + (progress * 0.5)
                buttonOpacity = progress
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
                // Snap to open position
                offset = -initialSwipeDistance
                buttonScale = 1.0
                buttonOpacity = 1.0
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
            buttonScale = 0.5
            buttonOpacity = 0
            onSwipeChanged(false)
        }
    }
    
    // MARK: - Delete Action with Smooth Disappearance
    private func performDelete() {
        isDeleting = true
        
        // Strong haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        // Smooth disappearance animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95)) {
            itemHeight = 0
            verticalPadding = -6 // Collapse the spacing too
            offset = -400 // Slide completely off screen
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

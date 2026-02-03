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
                        .onChange(of: activeSwipeID) { newValue in
                            // Close this item if another one becomes active
                            if let newValue = newValue, newValue != item.id {
                                // Trigger will be handled by isActive binding
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Swipe to Delete")
        }
    }
    
    private func deleteItem(_ item: SwipeItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
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
    
    private let deleteButtonWidth: CGFloat = 90
    private let swipeThreshold: CGFloat = 45
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button (always behind)
            deleteButton
            
            // Main content
            itemContent
                .offset(x: offset)
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
                        // Close this item when another becomes active
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                            offset = 0
                        }
                    }
                }
        }
        .frame(height: 80)
        .opacity(isDeleting ? 0 : 1)
        .scaleEffect(isDeleting ? 0.8 : 1)
    }
    
    // MARK: - Delete Button (iMessage style)
    private var deleteButton: some View {
        HStack(spacing: 0) {
            Spacer()
            
            Button(action: {
                performDelete()
            }) {
                ZStack {
                    Rectangle()
                        .fill(Color.red)
                    
                    Text("Delete")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: deleteButtonWidth)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 80)
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
                }
                .padding(.horizontal, 20)
            )
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        
        // Only allow left swipe (negative translation)
        if translation < 0 {
            // Apply resistance when swiping beyond the delete button
            let resistance: CGFloat = 3.0
            let rawOffset = translation
            
            if rawOffset < -deleteButtonWidth {
                let excess = rawOffset + deleteButtonWidth
                offset = -deleteButtonWidth + (excess / resistance)
            } else {
                offset = rawOffset
            }
        } else if offset < 0 {
            // Allow right swipe to close when already open
            let newOffset = offset + translation
            offset = min(newOffset, 0)
        }
    }
    
    private func handleDragEnded(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        let velocity = gesture.predictedEndTranslation.width - translation
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            if offset < -swipeThreshold || velocity < -200 {
                // Snap to show delete button
                offset = -deleteButtonWidth
                onSwipeChanged(true)
            } else {
                // Snap back to closed position
                offset = 0
                onSwipeChanged(false)
            }
        }
    }
    
    // MARK: - Delete Action
    private func performDelete() {
        isDeleting = true
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        // Delay to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDelete()
        }
    }
}

// MARK: - Preview
#Preview {
    SwipeAction()
}

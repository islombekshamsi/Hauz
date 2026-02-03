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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        SwipeableItemView(
                            item: item,
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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            items.removeAll { $0.id == item.id }
        }
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
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var isSwiping: Bool = false
    @State private var showDeleteButton: Bool = false
    
    private let deleteButtonWidth: CGFloat = 80
    private let swipeThreshold: CGFloat = 60
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button background
            deleteButtonBackground
            
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
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Delete Button Background
    private var deleteButtonBackground: some View {
        HStack {
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    onDelete()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Delete")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .scaleEffect(showDeleteButton ? 1.0 : 0.8)
                    .opacity(showDeleteButton ? 1.0 : 0.0)
                }
                .frame(width: deleteButtonWidth)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Item Content
    private var itemContent: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(item.color.gradient)
            .frame(height: 80)
            .overlay(
                HStack {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .opacity(isSwiping ? 0.5 : 0.3)
                }
                .padding(.horizontal, 20)
            )
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - Gesture Handlers
    private func handleDragChanged(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        
        // Only allow left swipe
        if translation < 0 {
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.9)) {
                offset = max(translation, -deleteButtonWidth)
                isSwiping = true
                showDeleteButton = offset < -20
            }
        }
    }
    
    private func handleDragEnded(_ gesture: DragGesture.Value) {
        let translation = gesture.translation.width
        let velocity = gesture.predictedEndTranslation.width
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if translation < -swipeThreshold || velocity < -100 {
                // Snap to show delete button
                offset = -deleteButtonWidth
                showDeleteButton = true
            } else {
                // Snap back to original position
                offset = 0
                showDeleteButton = false
            }
            isSwiping = false
        }
    }
}

// MARK: - Preview
#Preview {
    SwipeAction()
}

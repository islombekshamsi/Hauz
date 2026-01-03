import SwiftUI

struct ClaudeSwipeActin: View {
    @State private var items: [ChatItem] = [
        ChatItem(name: "John Doe", message: "Hey, are we still meeting tomorrow?"),
        ChatItem(name: "Jane Smith", message: "Thanks for the help earlier!"),
        ChatItem(name: "Work Team", message: "Meeting at 3 PM confirmed"),
        ChatItem(name: "Mom", message: "Call me when you can"),
        ChatItem(name: "Sarah Wilson", message: "Did you see the game last night?")
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    iMessageSwipeRow(item: item) {
                        withAnimation {
                            items.removeAll { $0.id == item.id }
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
        }
    }
}

struct ChatItem: Identifiable {
    let id = UUID()
    let name: String
    let message: String
}

struct iMessageSwipeRow: View {
    let item: ChatItem
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var showingActions = false
    
    private let fullSwipeThreshold: CGFloat = -200
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons background
            HStack(spacing: 0) {
                Spacer()
                
                actionButtons
            }
            
            // Main content
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(item.name.prefix(1)))
                            .foregroundColor(.white)
                            .font(.title3)
                            .fontWeight(.medium)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                    
                    Text(item.message)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let translation = gesture.translation.width
                        
                        if translation < 0 {
                            // Swiping left - show actions
                            offset = translation
                        } else if showingActions {
                            // Swiping right - close actions
                            offset = min(0, -88 + translation)
                        }
                    }
                    .onEnded { gesture in
                        let translation = gesture.translation.width
                        let velocity = gesture.predictedEndTranslation.width - translation
                        
                        // Full swipe to delete
                        if offset < fullSwipeThreshold || velocity < -1000 {
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = -500
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDelete()
                            }
                        }
                        // Show actions
                        else if offset < -44 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = -88
                                showingActions = true
                            }
                        }
                        // Close actions
                        else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                offset = 0
                                showingActions = false
                            }
                        }
                    }
            )
        }
        .background(Color(.systemBackground))
    }
    
    private var actionButtons: some View {
        HStack(spacing: 0) {
            Button(action: {}) {
                VStack(spacing: 4) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 20))
                    Text("Pin")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .frame(width: 88)
                .frame(maxHeight: .infinity)
            }
            .background(Color.orange)
            
            Button(action: {
                withAnimation {
                    onDelete()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                    Text("Delete")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .frame(width: 88)
                .frame(maxHeight: .infinity)
            }
            .background(Color.red)
        }
        .offset(x: min(0, offset + 176))
    }
}

#Preview {
    ClaudeSwipeActin()
}

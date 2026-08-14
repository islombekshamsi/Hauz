import SwiftUI

// MARK: - Main Demo View
struct iMessageSwipeDemo: View {
    @State private var messages: [Message] = Message.sampleData
    
    var body: some View {
        NavigationStack {
            List {
                ForEach($messages) { $message in
                    MessageRow(message: message)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .swipeToDelete(
                            onDelete: {
                                deleteMessage(message.id)
                            }
                        )
                }
            }
            .listStyle(.plain)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Reset") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            messages = Message.sampleData
                        }
                    }
                }
            }
        }
    }
    
    private func deleteMessage(_ id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            messages.removeAll { $0.id == id }
        }
    }
}

// MARK: - Message Model
struct Message: Identifiable {
    let id = UUID()
    let sender: String
    let content: String
    let time: String
    let isRead: Bool
    
    static let sampleData: [Message] = [
        Message(sender: "John Doe", content: "Hey! How's the project going?", time: "9:41 AM", isRead: true),
        Message(sender: "Apple", content: "Your receipt for App Store purchase", time: "Yesterday", isRead: true),
        Message(sender: "Mom", content: "Don't forget dinner on Sunday!", time: "Yesterday", isRead: false),
        Message(sender: "Sarah Wilson", content: "Can you send me those files?", time: "Friday", isRead: true),
        Message(sender: "Netflix", content: "New shows added to your list", time: "Thursday", isRead: true),
        Message(sender: "Alex Johnson", content: "Meeting rescheduled to 3 PM", time: "Wednesday", isRead: false),
        Message(sender: "Bank of America", content: "Your statement is ready", time: "Tuesday", isRead: true),
        Message(sender: "Mike Chen", content: "Let's grab lunch tomorrow", time: "Monday", isRead: true),
        Message(sender: "Amazon", content: "Your package has been delivered", time: "Sunday", isRead: true),
        Message(sender: "Emily Roberts", content: "Thanks for your help yesterday!", time: "Saturday", isRead: false),
    ]
}

// MARK: - Message Row View
struct MessageRow: View {
    let message: Message
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile circle
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(message.sender.prefix(1)))
                        .font(.title3.bold())
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(message.sender)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(message.time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if !message.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Swipe to Delete Modifier
struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void
    
    @State private var offset: CGFloat = 0
    @State private var initialOffset: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var isDeleting = false
    
    // iMessage-style constants
    private let deleteButtonSize: CGFloat = 58
    private let revealThreshold: CGFloat = 60
    private let fullRevealDistance: CGFloat = 100
    private let maxRevealDistance: CGFloat = 120
    
    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Delete Button (behind content)
            DeleteButton(
                progress: progress,
                isDeleting: isDeleting,
                onDelete: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isDeleting = true
                        offset = -UIScreen.main.bounds.width
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onDelete()
                    }
                }
            )
            
            // Content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleDragChange(value)
                        }
                        .onEnded { value in
                            handleDragEnd(value)
                        }
                )
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.3), value: offset)
        }
        .onChange(of: isDeleting) { oldValue, newValue in
            if newValue {
                // Reset after deletion animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    offset = 0
                    progress = 0
                    initialOffset = 0
                    isDeleting = false
                }
            }
        }
    }
    
    private func handleDragChange(_ value: DragGesture.Value) {
        let translationX = value.translation.width
        
        if value.startLocation.x < 50 { // Prevent swipe from very edge
            return
        }
        
        if abs(translationX) < 5 { // Dead zone for tiny movements
            return
        }
        
        // Only allow left swipes (negative translation)
        if translationX > 0 {
            offset = 0
            return
        }
        
        let newOffset = translationX + initialOffset
        
        if newOffset < -maxRevealDistance {
            // Rubber band effect when swiping past max
            let extra = abs(newOffset) - maxRevealDistance
            offset = -(maxRevealDistance + extra * 0.3)
        } else {
            offset = newOffset
        }
        
        // Calculate progress for button animation
        progress = min(max(abs(offset) / fullRevealDistance, 0), 1)
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        let velocityX = value.velocity.width
        
        // Determine if we should reveal or reset
        if abs(offset) > revealThreshold || velocityX < -200 {
            // Snap to full reveal
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = -fullRevealDistance
                progress = 1
            }
        } else {
            // Snap back
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                offset = 0
                progress = 0
            }
        }
        
        initialOffset = offset
    }
}

// MARK: - Delete Button (Expanding Circle)
struct DeleteButton: View {
    let progress: CGFloat
    let isDeleting: Bool
    let onDelete: () -> Void
    
    private let diameter: CGFloat = 58
    @State private var showConfirmation = false
    
    var body: some View {
        let buttonWidth = calculateButtonWidth()
        let iconOpacity = calculateIconOpacity()
        
        Button(action: {
            if !isDeleting {
                onDelete()
            }
        }) {
            ZStack {
                // Expanding circle background
                Capsule()
                    .fill(Color.red.gradient)
                    .frame(width: buttonWidth, height: diameter)
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: progress)
                
                // Trash icon
                Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(iconOpacity)
                    .scaleEffect(isDeleting ? 0.8 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDeleting)
            }
            .frame(width: diameter, height: diameter, alignment: .trailing)
        }
        .buttonStyle(DeleteButtonStyle())
        .padding(.trailing, 12)
        .disabled(isDeleting)
    }
    
    private func calculateButtonWidth() -> CGFloat {
        if isDeleting {
            return diameter * 0.7
        }
        
        // Ease-out curve for expansion
        let easedProgress = 1 - pow(1 - min(progress, 1), 2)
        return max(2, diameter * easedProgress)
    }
    
    private func calculateIconOpacity() -> Double {
        if isDeleting {
            return 0.7
        }
        
        // Icon appears after 40% expansion
        let iconThreshold: CGFloat = 0.4
        if progress < iconThreshold {
            return 0
        }
        return min((progress - iconThreshold) / (1 - iconThreshold), 1)
    }
}

// MARK: - Button Style for Delete Button
struct DeleteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - View Extension for Easy Usage
extension View {
    func swipeToDelete(onDelete: @escaping () -> Void) -> some View {
        self.modifier(SwipeToDeleteModifier(onDelete: onDelete))
    }
}

// MARK: - Custom Haptic Feedback
class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func playLightHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func playMediumHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Preview
#Preview {
    iMessageSwipeDemo()
        .preferredColorScheme(.dark)
}

// MARK: - Custom Modifier for Smooth Interaction
struct SwipeInteractionModifier: ViewModifier {
    @State private var isDragging = false
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { _ in isDragging = true }
                    .onEnded { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isDragging = false
                        }
                    }
            )
            .sensoryFeedback(.selection, trigger: isDragging)
    }
}

// MARK: - Additional Demo Content
struct AdditionalDemoContent: View {
    @State private var showDeleteAnimation = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("iMessage Swipe Demo")
                .font(.largeTitle.bold())
            
            VStack(alignment: .leading, spacing: 12) {
                Text("How it works:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Label("Swipe left on any message", systemImage: "arrow.left")
                    Label("Red circle expands as you swipe", systemImage: "circle.inset.filled")
                    Label("Tap the red button to delete", systemImage: "trash.circle.fill")
                    Label("Release to cancel swipe", systemImage: "arrow.uturn.left")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showDeleteAnimation.toggle()
                }
            } label: {
                Label("Show Delete Animation", systemImage: "trash")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            if showDeleteAnimation {
                DeleteButtonPreview()
                    .transition(.scale.combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview Delete Button
struct DeleteButtonPreview: View {
    @State private var progress: CGFloat = 0
    @State private var isDeleting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Delete Button Preview")
                .font(.headline)
            
            DeleteButton(progress: progress, isDeleting: isDeleting) {
                isDeleting = true
            }
            
            Slider(value: $progress, in: 0...1)
                .padding(.horizontal)
            
            HStack {
                Button("Reset") {
                    withAnimation {
                        progress = 0
                        isDeleting = false
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Delete") {
                    withAnimation {
                        isDeleting = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Main App Entry
#Preview{
    iMessageSwipeDemo()
}

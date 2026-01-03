import SwiftUI

struct SheetView: View {
    @State private var showSheet = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Button to trigger sheet
            Button(action: {
                showSheet.toggle()
            }) {
                Text("Show Options")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showSheet) {
            GlassOptionsSheet()
        }
    }
}

struct GlassOptionsSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Background with blur effect
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Choose Platform")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                // StockX Option
                OptionCard(
                    title: "StockX",
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: .green,
                    price: "$299"
                )
                
                // GOAT Option
                OptionCard(
                    title: "GOAT",
                    icon: "hare.fill",
                    accentColor: .orange,
                    price: "$285"
                )
                
                Spacer()
                
                // Close button
                Button(action: {
                    dismiss()
                }) {
                    Text("Cancel")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .padding()
        }
        .background(.ultraThinMaterial)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct OptionCard: View {
    let title: String
    let icon: String
    let accentColor: Color
    let price: String
    
    var body: some View {
        Button(action: {
            // Handle selection
            print("\(title) selected")
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(accentColor)
                    .frame(width: 50, height: 50)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(accentColor.opacity(0.2))
                    )
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 30)
        }
    }
}

#Preview {
    SheetView()
}

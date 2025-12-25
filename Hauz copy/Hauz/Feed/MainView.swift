import SwiftUI

// MARK: - Main View
struct MainView: View {
    @State private var filters: [String] = ["Sneakers","Style"]
    @AppStorage("hauz_home_filter") private var selectedFilter = "Sneakers"
    @State private var cards = [
        CardData(id: 1, shoeName: "ASICS Gel-1130", brandName: "ASICS", price: 120.00, shoeImage: "asics_forpreview", priceTrendIsUp: true, priceChangePercentage: 0.9),
        CardData(id: 2, shoeName: "Jordan 1s", brandName: "Air Jordan", price: 180.00, shoeImage: "aj1_forpreview", priceTrendIsUp: false, priceChangePercentage: 0.5),
    ]
    
    var body: some View {
        ZStack {
            Color("HauzLight")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                HauzFilterView(options: filters, selection: $selectedFilter)
                    .background(
                        Divider(), alignment: .bottom
                    )
                
                Spacer().frame(height: 5)
                
                if selectedFilter == "Sneakers" {
                    SneakersView()
                } else {
                    StyleView()
                }
                
                // Card stack container
                
                
                Spacer()
            }
        }
    }
    
    func indexOf(_ card: CardData) -> Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    
    func removeCard(_ card: CardData) {
        withAnimation {
            cards.removeAll { $0.id == card.id }
        }
    }
}

struct SneakersView: View {
    @State private var cards = [
        CardData(id: 1, shoeName: "ASICS Gel-1130", brandName: "ASICS", price: 120.00, shoeImage: "asics_forpreview", priceTrendIsUp: true, priceChangePercentage: 0.9),
        CardData(id: 2, shoeName: "Jordan 1s", brandName: "Air Jordan", price: 180.00, shoeImage: "aj1_forpreview", priceTrendIsUp: false, priceChangePercentage: 0.5),
    ]
    var body: some View {
        ZStack {
            ForEach(cards) { card in
                CardView(card: card) {
                    removeCard(card)
                }
                .stacked(at: indexOf(card), in: cards.count)
            }
        }
        .frame(height: 620)
        
        
        if cards.isEmpty {
            Text("Ran out of shoes. Wait a minute!")
        }
    }
    
    func indexOf(_ card: CardData) -> Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    
    func removeCard(_ card: CardData) {
        withAnimation {
            cards.removeAll { $0.id == card.id }
        }
    }
}

// MARK: - Card Data Model
struct CardData: Identifiable {
    let id: Int
    let shoeName: String
    let brandName: String
    let price: Double
    let shoeImage: String
    var priceTrendIsUp: Bool
    var priceChangePercentage: Double
}

// MARK: - Individual Card View
struct CardView: View {
    let card: CardData
    let onRemove: () -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    private var trendColor: Color {
        card.priceTrendIsUp ? Color.green : Color.red
    }
    
    private var trendIcon: String {
        card.priceTrendIsUp ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var formattedPrice: String {
        "$\(Int(card.price))"
    }
    
    private var formattedTrend: String {
        let sign = card.priceTrendIsUp ? "+" : "-"
        return "\(sign)\(String(format: "%.1f", abs(card.priceChangePercentage)))%"
    }
    
    var body: some View {
        ZStack {
            // Content container
            VStack(spacing: 0) {
                // Image section - takes up most of the card
                imageSection
                    .frame(height: 340)
                
                // Info section - compact bottom area
                infoSection
                    .frame(height: 220)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(Color("HauzFocus"), lineWidth: 3)
            )
            .shadow(
                color: Color.black.opacity(0.08),
                radius: 30,
                x: 0,
                y: 20
            )
            
            // LIKE ICON (Green checkmark) - appears when swiping right
            Image(systemName: "cart")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                .opacity(offset.width > 0 ? Double(offset.width / 100) : 0)
                .rotationEffect(.degrees(-25))
                .padding(.leading, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 60)
            
            // NOPE ICON (Red X) - appears when swiping left
            Image(systemName: "trash")
                .font(.system(size: 100))
                .foregroundColor(.red)
                .opacity(offset.width < 0 ? Double(-offset.width / 100) : 0)
                .rotationEffect(.degrees(25))
                .padding(.trailing, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 60)
        }
        .frame(width: 360, height: 560)
        .offset(x: offset.width, y: offset.height)
        .rotationEffect(.degrees(rotation))
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset = gesture.translation
                    rotation = Double(gesture.translation.width / 20)
                }
                .onEnded { gesture in
                    let swipeThreshold: CGFloat = 100
                    
                    if abs(gesture.translation.width) > swipeThreshold {
                        let direction: CGFloat = gesture.translation.width > 0 ? 1 : -1
                        withAnimation(.spring()) {
                            offset = CGSize(width: direction * 500, height: gesture.translation.height)
                            rotation = Double(direction * 20)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onRemove()
                        }
                    } else {
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
    
    // MARK: - Image Section
    private var imageSection: some View {
        ZStack {
            // Pure white background
            Color.white
            
            Image(card.shoeImage)
                .resizable()
                .scaledToFit()
                .frame(width: 300, height: 300)
                .padding(20)
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                // Price - most important, biggest
                Text(formattedPrice)
                    .font(.custom("HooverVariable-Bold", size: 42))
                    .foregroundColor(Color("HauzFocus"))
                
                // Shoe name - second priority
                Text(card.shoeName)
                    .font(.custom("HooverVariable-Bold_Medium", size: 22))
                    .foregroundColor(Color("HauzFocus"))
                    .lineLimit(1)
                
                // Brand name - third priority
                Text(card.brandName)
                    .font(.custom("HooverVariable-Bold_Regular", size: 14))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 13, weight: .bold))
                    Text(formattedTrend)
                        .font(.custom("HooverVariable-Bold_Regular", size: 15))
                }
                .foregroundColor(trendColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(trendColor.opacity(0.12))
                )
                
                Spacer()
                
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text("View")
                            .font(.custom("HooverVariable-Bold_Regular", size: 14))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color("HauzFocus"))
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color.white)
    }
}

// MARK: - Card Stacking Extension
extension View {
    func stacked(at position: Int, in total: Int) -> some View {
        let offset = Double(position) * 10
        return self
            .offset(y: offset)
            .scaleEffect(1 - Double(position) * 0.05)
            .zIndex(Double(total - position))
    }
}

private var header: some View {
    HStack(spacing: 0) {
        Text("Hauz")
            .font(.custom("HooverVariable-Bold_Regular", size: 45))
            .bold()
            .foregroundStyle(Color("HauzFocus"))
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color("HauzLight"))
    }
    .font(.title2)
    .fontWeight(.medium)
    .foregroundStyle(Color.black)
}

struct StyleView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color("HauzLight")
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated icon
                ZStack {
                    // Outer rotating circle
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color("HauzFocus").opacity(0.3),
                                    Color("HauzFocus").opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(
                            .linear(duration: 8)
                                .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                    
                    // Inner pulsing circle
                    Circle()
                        .fill(Color("HauzFocus").opacity(0.08))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                        .animation(
                            .easeInOut(duration: 2)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    // Main icon
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color("HauzFocus"))
                }
                .padding(.bottom, 10)
                
                // Text content
                VStack(spacing: 12) {
                    Text("Coming Soon")
                        .font(.custom("HooverVariable-Bold", size: 32))
                        .foregroundColor(Color("HauzFocus"))
                    
                    Text("We're working on something\namazing for you!")
                        .font(.custom("HooverVariable-Bold_Regular", size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Decorative badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text("Style Feed")
                        .font(.custom("HooverVariable-Bold_Regular", size: 14))
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Color("HauzFocus"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color("HauzFocus").opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(Color("HauzFocus").opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    MainView()
}

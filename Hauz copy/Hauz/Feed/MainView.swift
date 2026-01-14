import SwiftUI

// MARK: - Main View
struct MainView: View {
    @State private var filters: [String] = ["Sneakers","Style"]
    @AppStorage("hauz_main_filter") private var selectedFilter = "Sneakers"
    @ObservedObject var feedService: FeedService
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var showFilterSettings = false
    
    var body: some View {
        ZStack {
            Color("HauzBg")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                HStack(spacing: 0) {
                    HauzFilterView(options: filters, selection: $selectedFilter)
                }
                .background(
                    Divider(), alignment: .bottom
                )
                
                Spacer().frame(height: 5)
                
                if selectedFilter == "Sneakers" {
                    SneakersView(
                        cards: feedService.feed.map { $0.asCardData },
                        isLoadingMore: isLoadingMore,
                        noResultsForFilters: feedService.noResultsForFilters,
                        onSwipe: { id, direction in
                            Task {
                                await feedService.swipe(SwipeEvent(sneakerID: id, direction: direction))
                            }
                        },
                        onNeedMore: {
                            Task {
                                guard !isLoadingMore else { return }
                                isLoadingMore = true
                                await feedService.loadMore()
                                isLoadingMore = false
                            }
                        }
                    )
                } else {
                    StyleView()
                }
                
                Spacer()
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                    .scaleEffect(1.2)
            }
        }
        .task {
            if feedService.feed.isEmpty {
                isLoading = true
                await feedService.load()
                isLoading = false
            }
        }
    }
}

struct SneakersView: View {
    let cards: [CardData]
    let isLoadingMore: Bool
    let noResultsForFilters: Bool
    var onSwipe: (UUID, String) -> Void
    var onNeedMore: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            if cards.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    if isLoadingMore {
                        ProgressView("Loading more...")
                            .progressViewStyle(CircularProgressViewStyle(tint: Color("HauzFocus")))
                            .foregroundColor(.secondary)
                    } else if noResultsForFilters {
                        // No shoes match the current filters
                        VStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 50))
                                .foregroundColor(Color("HauzFocus").opacity(0.5))
                            
                            Text("No shoes found")
                                .font(.custom("bernoru-blackultraexpanded", size: 20))
                                .foregroundColor(.primary)
                            
                            Text("Try adjusting your filters\n(price range, gender, or brands)")
                                .font(.custom("bernoru-blackultraexpanded", size: 12))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        // Ran out of shoes but can load more
                        Text("Ran out of shoes.")
                            .font(.custom("bernoru-blackultraexpanded", size: 18))
                            .foregroundColor(.secondary)
                        Text("Tap below to load more sneakers.")
                            .font(.custom("bernoru-blackultraexpanded", size: 12))
                            .foregroundColor(.secondary)
                        
                        Button {
                            onNeedMore()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Load more")
                            }
                            .font(.custom("bernoru-blackultraexpanded", size: 16))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(Color("HauzFocus"))
                            )
                            .foregroundColor(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                Spacer()
            } else {
                // Limit the visible stack to keep the layout tidy
                let visibleCards = Array(cards.prefix(5))
                
                ZStack {
                    ForEach(visibleCards) { card in
                        CardView(card: card) { direction in
                            onSwipe(card.id, direction)
                        }
                        .stacked(at: indexOf(card), in: visibleCards.count)
                    }
                }
                .frame(height: 640)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: cards)
                // No button until the deck is empty
            }
        }
    }
    
    func indexOf(_ card: CardData) -> Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
}

// MARK: - Card Data Model
struct CardData: Identifiable, Equatable {
    let id: UUID
    let shoeName: String
    let brandName: String
    let price: Double?
    let imageURL: URL?
    var priceTrendIsUp: Bool
    var priceChangePercentage: Double
    let stockxLink: String?
}

private extension SneakerCard {
    var asCardData: CardData {
        CardData(
            id: id,
            shoeName: name,
            brandName: brand,
            price: price,
            imageURL: imageURL,
            priceTrendIsUp: true,
            priceChangePercentage: 1.0,
            stockxLink: stockxLink
        )
    }
}

// MARK: - Individual Card View
struct CardView: View {
    let card: CardData
    let onSwipe: (String) -> Void
    
    @State private var offset = CGSize.zero
    @State private var rotation: Double = 0
    
    private var trendColor: Color {
        card.priceTrendIsUp ? Color.green : Color.red
    }
    
    private var trendIcon: String {
        card.priceTrendIsUp ? "arrow.up.right" : "arrow.down.right"
    }
    
    private var formattedPrice: String {
        if let price = card.price {
            return "$\(Int(price))"
        }
        return "$—"
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
                    .frame(height: 360)
                
                // Info section - compact bottom area
                infoSection
                    .frame(height: 200)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
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
        .frame(width: 360, height: 400)
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
                        
                        let dirString = direction > 0 ? "right" : "left"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.spring()) {
                                onSwipe(dirString)
                            }
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
            
            if let url = card.imageURL {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding(20)
                } placeholder: {
                    ProgressView()
                }
            } else {
                Image("asics_forpreview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .padding(20)
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                // Price - most important, biggest
                Text(formattedPrice)
                    .font(.custom("Outfit-Black", size: 60))
                    .foregroundColor(Color("HauzBg"))
                
                // Shoe name - second priority
                Text(card.shoeName)
                    .font(.custom("Outfit-SemiBold", size: 15))
                    .foregroundColor(Color("HauzFocus"))
                    .lineLimit(2)
                
                // Brand name - third priority
                Text(card.brandName)
                    .font(.custom("Outfit-SemiBold", size: 12))
                    .foregroundColor(Color("HauzFocus"))
            }
            
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 13, weight: .bold))
                    Text(formattedTrend)
                        .font(.custom("bernoru-blackultraexpanded", size: 13))
                }
                .foregroundColor(trendColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(trendColor.opacity(0.12))
                )
                
                Spacer()
                
                Button(action: {
                    if let link = card.stockxLink, let url = URL(string: link) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("View")
                            .font(.custom("Outfit-Medium", size: 20))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color("HauzBg"))
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .disabled(card.stockxLink == nil)
                .opacity(card.stockxLink == nil ? 0.5 : 1.0)
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
            .font(.custom("bernoru-blackultraexpanded", size: 40))
            .foregroundStyle(Color("HauzFocus"))
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color("HauzBg"))
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
            Color("HauzBg")
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
                        .font(.custom("Outfit-Black", size: 30))
                        .foregroundColor(Color("HauzFocus"))
                        .multilineTextAlignment(.center)
                    
                    Text("We're working on something\namazing for you!")
                        .font(.custom("Outfit-SemiBold", size: 15))
                        .foregroundColor(Color("HauzLight"))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Decorative badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                    Text("Style Feed")
                        .font(.custom("Outfit-Black", size: 10))
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
    ContentView()
}

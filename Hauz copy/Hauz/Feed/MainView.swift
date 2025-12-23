import SwiftUI

// MARK: - Main View
struct MainView: View {
    // Array of cards to display
    // CUSTOMIZE: Add more cards or change colors here
    @State private var filters: [String] = ["Sneakers","Style"]
    @AppStorage("hauz_home_filter") private var selectedFilter = "Sneakers" // saves the state user's at, if user closes the app it will rememeber it.
    @State private var cards = [
        CardData(id: 1, shoeName: "ASICS Gel-1130", brandName: "ASICS", price: 120.00, shoeImage: "asics_forpreview", priceTrendIsUp: true, priceChangePercentage: 0.9),
        CardData(id: 2, shoeName: "Jordan 1s", brandName: "Air Jordan", price: 180.00, shoeImage: "aj1_forpreview", priceTrendIsUp: false, priceChangePercentage: 0.5),
    ]
    
    var body: some View {
        ZStack {
            // Background color
            // CUSTOMIZE: Change background color here
            Color("HauzLight")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Title text
                // CUSTOMIZE: Change title text or styling here
                header
                
                HauzFilterView(options: filters, selection: $selectedFilter)
                    .background(
                        Divider(), alignment: .bottom
                    )
                
                Spacer().frame(height: 20)
                
                // Card stack container
                ZStack {
                    // Loop through all cards and display them
                    ForEach(cards) { card in
                        CardView(card: card) {
                            removeCard(card)
                        }
                        .stacked(at: indexOf(card), in: cards.count)
                    }
                }
                // CUSTOMIZE: Adjust this height if cards are cut off
                .frame(height: 610) // Adjusted height for stacked cards further
                
                Spacer()
                
                // Show reset button when all cards are gone
                if cards.isEmpty {
                    Text("Ran out of shoes. Wait a minute!") // change to loading button.
                }
                
                Spacer()
            }
        }
    }
    
    // Find the position of a card in the array
    func indexOf(_ card: CardData) -> Int {
        cards.firstIndex(where: { $0.id == card.id }) ?? 0
    }
    
    // Remove a card from the deck after swiping
    func removeCard(_ card: CardData) {
        withAnimation {
            cards.removeAll { $0.id == card.id }
        }
    }
    
    // Reset the deck to initial state
    // CUSTOMIZE: Change the cards that appear when resetting
    
}

// MARK: - Card Data Model
// Defines the data structure for each card
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
    
    // Track the card's position as user drags it
    @State private var offset = CGSize.zero
    // Track the rotation angle based on horizontal drag
    @State private var rotation: Double = 0
    
    // CUSTOMIZE: Computed properties for dynamic styling
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
            // Main card container with subtle shadow
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.white)
                .shadow(
                    color: Color.black.opacity(0.08),
                    radius: 30, // Fixed radius as isPressed is removed
                    x: 0,
                    y: 20 // Fixed y-offset as isPressed is removed
                )
            
            VStack(spacing: 0) {
                // Image section - takes up most of the card
                imageSection
                    .frame(height: 320) // Reduced image section height
                
                // Info section - compact bottom area
                infoSection
                    .frame(height: 180)
            }
            
            // LIKE ICON (Green checkmark) - appears when swiping right
            // CUSTOMIZE: Change icon, color, size, or position here
            Image(systemName: "cart")
                .font(.system(size: 100))
                .foregroundColor(.blue)
                // Opacity increases as you swipe right (offset.width / 100)
                // CUSTOMIZE: Change divisor (100) to make icon appear faster/slower
                .opacity(offset.width > 0 ? Double(offset.width / 100) : 0)
                .rotationEffect(.degrees(-25))
                .padding(.leading, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 60)
            
            // NOPE ICON (Red X) - appears when swiping left
            // CUSTOMIZE: Change icon, color, size, or position here
            Image(systemName: "trash")
                .font(.system(size: 100))
                .foregroundColor(.red)
                // Opacity increases as you swipe left (-offset.width / 100)
                // CUSTOMIZE: Change divisor (100) to make icon appear faster/slower
                .opacity(offset.width < 0 ? Double(-offset.width / 100) : 0)
                .rotationEffect(.degrees(25))
                .padding(.trailing, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 60)
        }
        .frame(width: 360, height: 500) // Increased overall card height further
        // Apply the drag offset to move the card
        .offset(x: offset.width, y: offset.height)
        // Rotate the card based on horizontal drag
        .rotationEffect(.degrees(rotation))
        // Drag gesture handling
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    // Update position as user drags
                    offset = gesture.translation
                    // Calculate rotation: divide by 20 to make rotation subtle
                    // CUSTOMIZE: Change divisor to make rotation more/less pronounced
                    rotation = Double(gesture.translation.width / 20)
                }
                .onEnded { gesture in
                    // Swipe threshold: how far user needs to drag to trigger swipe
                    // CUSTOMIZE: Increase to require longer swipe, decrease for easier swipe
                    let swipeThreshold: CGFloat = 100
                    
                    // Check if user swiped past the threshold
                    if abs(gesture.translation.width) > swipeThreshold {
                        // Card was swiped far enough - send it flying off screen
                        let direction: CGFloat = gesture.translation.width > 0 ? 1 : -1
                        withAnimation(.spring()) {
                            // Animate card flying off screen (500 points off)
                            // CUSTOMIZE: Change 500 to make card fly further/less
                            offset = CGSize(width: direction * 500, height: gesture.translation.height)
                            rotation = Double(direction * 20)
                        }
                        
                        // Remove card after animation completes (0.3 seconds)
                        // CUSTOMIZE: Match this delay with animation duration if you change it
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onRemove()
                        }
                    } else {
                        // Card wasn't swiped far enough - return to center
                        withAnimation(.spring()) {
                            offset = .zero
                            rotation = 0
                        }
                    }
                }
        )
    }
    
    // MARK: - Image Section
    // Clean image display with subtle gradient background that blends seamlessly
    private var imageSection: some View {
        ZStack {
            // CUSTOMIZE: Subtle gradient background that creates depth
            LinearGradient(
                   colors: [
                       Color(red: 251/255, green: 252/255, blue: 255/255),   // FBFCFF
                       Color(red: 208/255, green: 204/255, blue: 208/255)
                           .opacity(0.35)                                   // D0CCD0
                   ],
                   startPoint: .top,
                   endPoint: .bottomTrailing
               )

               // Top-right soft accent blob
               Circle()
                   .fill(
                       RadialGradient(
                           colors: [
                               Color(red: 96/255, green: 88/255, blue: 86/255)
                                   .opacity(0.10),                           // 605856
                               Color.clear
                           ],
                           center: .center,
                           startRadius: 20,
                           endRadius: 140
                       )
                   )
                   .frame(width: 220, height: 400)
                   .blur(radius: 50)
                   .offset(x: 70, y: -100)

               // Bottom-left blob for balance
               Circle()
                   .fill(
                       RadialGradient(
                           colors: [
                               Color(red: 208/255, green: 204/255, blue: 208/255)
                                   .opacity(0.20),                           // D0CCD0
                               Color.clear
                           ],
                           center: .center,
                           startRadius: 20,
                           endRadius: 120
                       )
                   )
                   .frame(width: 200, height: 200)
                   .blur(radius: 45)
                   .offset(x: -60, y: 80)

               // Center glow for depth
               Ellipse()
                   .fill(
                       RadialGradient(
                           colors: [
                               Color(red: 96/255, green: 88/255, blue: 86/255)
                                   .opacity(0.08),                           // 605856
                               Color.clear
                           ],
                           center: .center,
                           startRadius: 30,
                           endRadius: 150
                       )
                   )
                   .frame(width: 280, height: 120)
                   .blur(radius: 40)
                   .offset(y: 20)
            
            // CUSTOMIZE: Main product image - STRAIGHT, NO ROTATION
            // Image is centered and blends naturally with the background
            Image(card.shoeImage)
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 250) // Increased image height further
                .padding(10)
                // REMOVED: .rotationEffect(.degrees(-15)) - Image is now straight
                .offset(y: 0) // Adjusted vertical offset
      
                .background(Color.white) // Removed explicit background
                 .clipShape(RoundedRectangle(cornerRadius: 25)) // Removed explicit clip shape
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                topTrailingRadius: 32
            )
        )
    }
    
    // MARK: - Info Section
    // Compact information display at bottom
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // CUSTOMIZE: Product name and price row
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.shoeName)
                        .font(.custom("HooverVariable-Bold_Medium", size: 25))
                        .foregroundColor(Color("HauzFocus"))
                        .lineLimit(1)
                    
                    Text(card.brandName)
                        .font(.custom("HooverVariable-Bold_Regular", size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // CUSTOMIZE: Price badge
                Text(formattedPrice)
                    .font(.custom("HooverVariable-Bold", size: 28))
                    .foregroundColor(Color("HauzFocus"))
            }
            
            // CUSTOMIZE: Stats row with trend indicator
            HStack(spacing: 12) {
                // Price trend badge
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
                
                // CUSTOMIZE: Action button - minimal design
                Button(action: {
                    // Action: View on StockX or similar
                }) {
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
                            .fill(
                                Color("HauzFocus")
                            )
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
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 32,
                bottomTrailingRadius: 32
            )
        )
    }

} // Corrected closing brace for CardView

// MARK: - Card Stacking Extension
// This creates the stacked card effect where cards behind are slightly offset and scaled
extension View {
    func stacked(at position: Int, in total: Int) -> some View {
        // Vertical offset for each card (10 points per position)
        // CUSTOMIZE: Change multiplier to increase/decrease spacing between stacked cards
        let offset = Double(position) * 10
        return self
            .offset(y: offset)
            // Scale each card slightly smaller (5% per position)
            // CUSTOMIZE: Change 0.05 to make size difference more/less pronounced
            .scaleEffect(1 - Double(position) * 0.05)
            // Z-index ensures cards are layered correctly
            .zIndex(Double(total - position))
    }
}

// MARK: - Card Stacking Extension
// This creates the stacked card effect where cards behind are slightly offset and scaled

private var header: some View{
    HStack(spacing: 0){
        /*HStack(spacing: 10){
            Image(systemName: "line.horizontal.3")
                .padding(8)
                .background(Color.black.opacity(0.001))
                .onTapGesture {
                    
                }
            
            Image(systemName: "arrow.uturn.left")
                .padding(8)
                .background(Color.black.opacity(0.001))
                .onTapGesture {
                    
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
         
         MARK: -those two are return and menu options at the top
         */
        
        Text("Hauz")
            .font(.custom("HooverVariable-Bold_Regular", size: 45))
            .bold()
            .foregroundStyle(Color("HauzLight"))
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color("HauzFocus"))
        /*Image(systemName: "slider.horizontal.3")
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(Color.black.opacity(0.001))
            .onTapGesture {
                
            }
         MARK: -this is in case you want filter at the top
         */
        
    }
    .font(.title2)
    .fontWeight(.medium)
    .foregroundStyle(Color.black) // replace with hauz's color
}

#Preview {
    MainView()
}

/*
 Hoover Variable
 -- HooverVariable-Bold_Regular
 -- HooverVariable-Bold_Thin
 -- HooverVariable-Bold_Light
 -- HooverVariable-Bold_Medium
 -- HooverVariable-Bold

 
 */

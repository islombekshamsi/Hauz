import SwiftUI

struct FlippableShoeCard: View {
    let card: CardData
    
    var body: some View {
        ZStack {
            // Pure white background
            Color.white
            
            // Main content
            VStack(spacing: 0) {
                // MASSIVE shoe section with price floating on top
                ZStack(alignment: .topTrailing) {
                    Color.white
                    
                    // Giant shoe image - the absolute star
                    Image(card.shoeImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 320, height: 200)
                        .padding(.vertical, 30)
                        .padding(.horizontal, 20)
                    
                    // Floating price badge - top right, clean and bold
                    Text("$\(Int(card.price))")
                        .font(.custom("HooverVariable-Bold", size: 28))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color("HauzFocus"))
                                .shadow(
                                    color: Color.black.opacity(0.15),
                                    radius: 12,
                                    x: 0,
                                    y: 4
                                )
                        )
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                }
                .frame(height: 260)
                
                // Sleek info bar
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.shoeName)
                            .font(.custom("HooverVariable-Bold_Medium", size: 17))
                            .foregroundColor(Color("HauzFocus"))
                            .lineLimit(1)
                        
                        Text(card.brandName)
                            .font(.custom("HooverVariable-Bold_Regular", size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // View button
                    Button(action: {}) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color("HauzFocus"))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.white)
            }
        }
        .frame(width: 360, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color("HauzFocus"), lineWidth: 3)
        )
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 20,
            x: 0,
            y: 10
        )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            FlippableShoeCard(
                card: CardData(
                    id: 1,
                    shoeName: "ASICS Gel-1130",
                    brandName: "ASICS",
                    price: 120.00,
                    shoeImage: "asics_forpreview",
                    priceTrendIsUp: true,
                    priceChangePercentage: 0.9
                )
            )
            
            FlippableShoeCard(
                card: CardData(
                    id: 2,
                    shoeName: "Jordan 1s",
                    brandName: "Air Jordan",
                    price: 180.00,
                    shoeImage: "aj1_forpreview",
                    priceTrendIsUp: false,
                    priceChangePercentage: 0.5
                )
            )
        }
        .padding()
    }
    .background(Color("HauzLight"))
}

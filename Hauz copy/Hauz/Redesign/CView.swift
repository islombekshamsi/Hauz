import SwiftUI
import UIKit

struct ShoeCard: Identifiable {
    var id: String = UUID().uuidString
    var price: Int
    var brand: String
    var name: String
    var image: String
    var link: String?
}

let shoes: [ShoeCard] = [
    ShoeCard(price: 155, brand: "Air Jordan", name: "Jordan 1 Retro High OG", image: "aj1_forpreview", link: "https://stockx.com/air-jordan-1-retro-high-og-chicago-reimagined-lost-and-found"),
    ShoeCard(price: 289, brand: "Air Jordan", name: "Jordan 11 Retro", image: "aj11_forpreview", link: "https://stockx.com/air-jordan-11-retro-canyon-purple"),
    ShoeCard(price: 100, brand: "ASICS", name: "ASICS Gel-1130", image: "asics_forpreview", link: "https://stockx.com/asics-gel-1130-black-pure-silver"),
]

struct CView: View {
    @State private var activeIndex: Int = 0
    @State private var showSearch = false
    @State private var searchText = ""

    private var activeShoe: ShoeCard {
        guard !shoes.isEmpty, shoes.indices.contains(activeIndex) else {
            return shoes.first ?? ShoeCard(price: 0, brand: "", name: "", image: "", link: nil)
        }
        return shoes[activeIndex]
    }

    var body: some View {
        ZStack {
            HeaderView {
                VStack(spacing: 0) {
                    AppleTVCarousel {
                        ForEach(shoes) { shoe in
                            Image(shoe.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    } scrollProgress: { progress in
                        activeIndex = min(Int(progress.rounded()), max(shoes.count - 1, 0))
                    }
                    .frame(height: 400)

                    BottomContent(activeShoe, onSearchTap: presentSearch)
                        .padding(.top, 16)
                        .padding(.horizontal, 20)

                    Spacer(minLength: 24)
                }
            }

            if showSearch {
                CViewSearchOverlay(
                    isPresented: $showSearch,
                    searchText: $searchText
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(200)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: showSearch)
    }

    private func presentSearch() {
        searchText = ""
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showSearch = true
        }
    }

    @ViewBuilder
    func BottomContent(_ shoe: ShoeCard, onSearchTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(shoe.brand.uppercased())
                .font(.custom("Outfit-Black", size: 11))
                .tracking(1.8)
                .foregroundStyle(Color("HauzFocus"))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(Color("HauzFocus").opacity(0.12))
                )

            Text(shoe.price, format: .currency(code: "USD"))
                .font(.custom("Outfit-Black", size: 50))
                .foregroundStyle(Color("HauzBg"))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, 6)

            Text(shoe.name)
                .font(.custom("Outfit-SemiBold", size: 15))
                .foregroundStyle(Color("HauzBg").opacity(0.5))
                .lineLimit(1)
                .padding(.top, 2)

            HStack(spacing: 8) {
                GlassButton(icon: "arrow.uturn.left") { }

                GlassButton(icon: "cart", action: {
                    if let link = shoe.link, let url = URL(string: link) {
                        UIApplication.shared.open(url)
                    }
                })
                .opacity(shoe.link == nil ? 0.35 : 1)
                .disabled(shoe.link == nil)

                GlassButton(icon: "magnifyingglass", action: onSearchTap)

                GlassButton(icon: "wand.and.sparkles", tint: Color("HauzFocus")) { }
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .animation(.easeOut(duration: 0.18), value: shoe.id)
    }
}

// MARK: - Search overlay (just the BorderContentView, floats up smoothly)

private struct CViewSearchOverlay: View {
    @Binding var isPresented: Bool
    @Binding var searchText: String

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismissSearch() }

            BorderContentView(text: $searchText, onDismiss: dismissSearch)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func dismissSearch() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            isPresented = false
            searchText = ""
        }
    }
}

private struct GlassButton: View {
    let icon: String
    var tint: Color = Color("HauzBg")
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(tint.opacity(0.15), lineWidth: 1)
                        }
                }
                .scaleEffect(pressed ? 0.92 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pressed = false }
                }
        )
    }
}

#Preview {
    CView()
}

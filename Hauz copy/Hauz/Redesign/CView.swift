import SwiftUI
import UIKit
import Combine

enum CViewTab: String, CaseIterable, Identifiable {
    case feed = "Feed"
    case collections = "Collections"
    case profile = "Profile"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .feed: return "hanger"
        case .collections: return "square.stack"
        case .profile: return "person.crop.circle"
        }
    }

    var actionSymbol: String {
        switch self {
        case .feed: return "slider.horizontal.3"
        case .collections: return "plus"
        case .profile: return "gearshape"
        }
    }
}

struct CView: View {
    @StateObject private var feedService = FeedService()
    @State private var activeIndex: Int = 0
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var activeTab: CViewTab = .feed
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasAttemptedLoad = false

    private var feed: [SneakerCard] { feedService.feed }

    private var activeShoe: SneakerCard? {
        guard !feed.isEmpty else { return nil }
        let safeIndex = min(max(activeIndex, 0), feed.count - 1)
        return feed[safeIndex]
    }

    var body: some View {
        ZStack {
            HeaderView {
                VStack(spacing: 0) {
                    if feed.isEmpty {
                        emptyOrLoadingView
                            .frame(height: 400)
                    } else {
                        AppleTVCarousel {
                            ForEach(feed) { shoe in
                                shoeImage(for: shoe)
                            }
                        } scrollProgress: { progress in
                            let newIndex = min(Int(progress.rounded()), max(feed.count - 1, 0))
                            if newIndex != activeIndex {
                                activeIndex = newIndex
                                maybeLoadMore()
                            }
                        }
                        .frame(height: 400)
                    }

                    if let shoe = activeShoe {
                        BottomContent(shoe, onSearchTap: presentSearch)
                            .padding(.top, 16)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                    }

                    Spacer(minLength: 0)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                CViewTabBar(activeTab: $activeTab)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
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
        .task {
            if feedService.feed.isEmpty && !hasAttemptedLoad {
                await reloadFeed()
            }
        }
    }

    @ViewBuilder
    private var emptyOrLoadingView: some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(Color("HauzFocus"))
                    .scaleEffect(1.2)
            } else if hasAttemptedLoad {
                VStack(spacing: 14) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(Color("HauzFocus").opacity(0.6))
                    VStack(spacing: 4) {
                        Text("No shoes loaded")
                            .font(.custom("Outfit-Black", size: 16))
                            .foregroundStyle(Color("HauzBg"))
                        Text("Make sure you're signed in,\nthen try reloading.")
                            .font(.custom("Outfit-Medium", size: 13))
                            .foregroundStyle(Color("HauzBg").opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        Task { await reloadFeed() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Reload")
                                .font(.custom("Outfit-SemiBold", size: 14))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color("HauzFocus")))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reloadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        hasAttemptedLoad = true
        await feedService.load()
        isLoading = false
    }

    @ViewBuilder
    private func shoeImage(for shoe: SneakerCard) -> some View {
        if let url = shoe.imageURL {
            AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    fallbackImage
                case .empty:
                    ProgressView()
                        .tint(Color("HauzFocus"))
                @unknown default:
                    fallbackImage
                }
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(systemName: "photo")
            .font(.system(size: 60, weight: .ultraLight))
            .foregroundStyle(Color("HauzBg").opacity(0.3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func presentSearch() {
        searchText = ""
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            showSearch = true
        }
    }

    private func maybeLoadMore() {
        guard !isLoadingMore else { return }
        // Trigger when user is within 3 cards of the end
        if activeIndex >= feed.count - 3 {
            Task {
                isLoadingMore = true
                await feedService.loadMore()
                isLoadingMore = false
            }
        }
    }

    @ViewBuilder
    func BottomContent(_ shoe: SneakerCard, onSearchTap: @escaping () -> Void) -> some View {
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

            Group {
                if let price = shoe.price {
                    Text(price, format: .currency(code: "USD"))
                } else {
                    Text("—")
                }
            }
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
                    if let link = shoe.stockxLink, let url = URL(string: link) {
                        UIApplication.shared.open(url)
                    }
                })
                .opacity(shoe.stockxLink == nil ? 0.35 : 1)
                .disabled(shoe.stockxLink == nil)

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

    private let suggestions = [
        "Jordan 1 Retro High OG",
        "Yeezy Boost 350",
        "Nike Dunk Low Panda",
        "New Balance 550",
        "ASICS Gel-1130",
        "Travis Scott Air Jordan 4",
        "Adidas Samba OG",
        "On Cloudmonster",
    ]
    @State private var suggestionIndex = 0
    private let cycleTimer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .center) {
                    VStack(spacing: 18) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 88, weight: .light))
                            .foregroundStyle(Color.primary.opacity(0.10))
                            .symbolRenderingMode(.hierarchical)

                        VStack(spacing: 6) {
                            Text("Try searching for")
                                .font(.custom("Outfit-Medium", size: 13))
                                .foregroundStyle(Color.primary.opacity(0.45))
                                .tracking(1.0)
                                .textCase(.uppercase)

                            Text(suggestions[suggestionIndex])
                                .font(.custom("Outfit-Black", size: 22))
                                .foregroundStyle(Color.primary.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .padding(.horizontal, 28)
                                .id(suggestionIndex)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .accessibilityHidden(true)
                    .padding(.bottom, 120)
                }
                .onReceive(cycleTimer) { _ in
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                        suggestionIndex = (suggestionIndex + 1) % suggestions.count
                    }
                }
                .borderBeam(
                    border: .primary,
                    beam: [.green, .blue, .pink, .orange, .indigo],
                    beamBlur: 18,
                    cornerRadius: 0,
                    isEnabled: true
                )
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

// MARK: - Tab bar (mirrors Feed/ContentView CustomTabBarView, 3 tabs)

private struct CViewTabBar: View {
    @Binding var activeTab: CViewTab

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                GeometryReader {
                    CViewCustomTabBar(size: $0.size, activeTab: $activeTab) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.symbol)
                                .font(.title2)
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }

                ZStack {
                    ForEach(CViewTab.allCases) { tab in
                        if activeTab == tab {
                            Image(systemName: tab.actionSymbol)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color("HauzFocus"))
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: activeTab)
            }
        }
        .frame(height: 50)
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

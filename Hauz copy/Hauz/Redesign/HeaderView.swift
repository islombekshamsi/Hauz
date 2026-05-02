import SwiftUI

struct HeaderView<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var selection: String = "For You"
    @State private var isSearchExtended: Bool = false
    @State private var isSearchActivated: Bool = false

    var body: some View {
        ScrollView(.vertical) {
            content()
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 2) {
                    Text("Hauz")
                        .font(.custom("bernoru-blackultraexpanded", size: 25))
                        .foregroundStyle(Color("NewVariant"))
                        .hAlign(.leading)
                }
                .padding(.horizontal)

                CustomHeader(
                    items: ["For You", "Popular", "Men", "Women"],
                    selection: $selection,
                    isSearchExpanded: $isSearchExtended
                ) { isKeyboardActive in
                    isSearchActivated = isKeyboardActive
                }
                .padding(.horizontal, 4)
            }
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension HeaderView where Content == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}

#Preview {
    HeaderView {
        Color.clear.frame(height: 8)
    }
}

//  CustomHeader.swift
//  Hauz

import SwiftUI

struct CustomHeader: View {
    var items: [String]
    @Binding var selection: String
    @Binding var isSearchExpanded: Bool
    var onSearchActivated: (Bool) -> ()

    @State private var itemWidths: [String: CGFloat] = [:]
    @State private var itemOffsets: [String: CGFloat] = [:]
    @State private var underlineWidth: CGFloat = 0
    @State private var underlineX: CGFloat = 0
    @State private var previousSelection: String = ""

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        ItemView(item)
                            .frame(width: proxy.size.width / CGFloat(items.count))
                            .background(
                                GeometryReader { geo in
                                    Color.clear.onAppear {
                                        itemWidths[item] = geo.size.width
                                        itemOffsets[item] = geo.frame(in: .named("scrollSpace")).minX
                                        if item == selection {
                                            underlineWidth = geo.size.width
                                            underlineX = geo.frame(in: .named("scrollSpace")).minX
                                            previousSelection = item
                                        }
                                    }
                                }
                            )
                    }
                }
                .frame(width: proxy.size.width)
                .coordinateSpace(name: "scrollSpace")
                .overlay(alignment: .bottomLeading) {
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: underlineWidth, height: 3)
                        .offset(x: underlineX)
                        .animation(expandAnimation, value: underlineWidth)
                        .animation(slideAnimation, value: underlineX)
                }
            }
            .scrollDisabled(true)
        }
        .frame(height: 50)
        .onChange(of: selection) { _, newValue in
            guard
                let targetWidth = itemWidths[newValue],
                let targetX = itemOffsets[newValue],
                let sourceX = itemOffsets[previousSelection],
                let sourceWidth = itemWidths[previousSelection]
            else { return }

            let movingRight = targetX > sourceX

            if movingRight {
                withAnimation(expandAnimation) {
                    underlineWidth = (targetX + targetWidth) - sourceX
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(contractAnimation) {
                        underlineX = targetX
                        underlineWidth = targetWidth
                    }
                }
            } else {
                withAnimation(expandAnimation) {
                    underlineX = targetX
                    underlineWidth = (sourceX + sourceWidth) - targetX
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(contractAnimation) {
                        underlineWidth = targetWidth
                    }
                }
            }

            previousSelection = newValue
        }
    }

    @ViewBuilder
    private func ItemView(_ item: String) -> some View {
        let isSelected = selection == item

        VStack(spacing: 6) {
            Text(item)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isSelected)

            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item
        }
    }

    private let expandAnimation: Animation = .interpolatingSpring(duration: 0.22, bounce: 0)
    private let contractAnimation: Animation = .interpolatingSpring(duration: 0.28, bounce: 0.15)
    private let slideAnimation: Animation = .interpolatingSpring(duration: 0.25, bounce: 0)
}
#Preview {
    HeaderView()
}

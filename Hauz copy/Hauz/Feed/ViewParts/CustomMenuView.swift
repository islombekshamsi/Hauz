import SwiftUI

struct CustomMenuView<Label: View, Content: View>: View {
    var style: CustomMenuStyle = .glass
    var isHapticsEnabled: Bool = true
    
    
    @ViewBuilder var label: Label
    @ViewBuilder var content: Content
    //view properties
    //optional haptics feedback
    @State private var haptics: Bool = false
    @State private var isExpanded: Bool = false
    
    var body: some View{
        Button{
            if isHapticsEnabled{
                haptics.toggle()
            }
            
            isExpanded.toggle()
        } label: {
            label
        }
        
        .applyStyle(style)
        .popover(isPresented: $isExpanded){
            content
                .presentationCompactAdaptation(.popover)
        }
        .sensoryFeedback(.selection, trigger: haptics)
    }
    
}


enum CustomMenuStyle: String, CaseIterable {
    case glass = "Glass"
    case glassProminent = "Glass Prominent"
}

fileprivate extension View{
    @ViewBuilder
    func applyStyle(_ style: CustomMenuStyle) -> some View {
        switch style{
        case .glass:
            self
                .buttonStyle(.glass)
            
        case .glassProminent:
            self
                .buttonStyle(.glassProminent)
        }
    }
}

struct view: View{
    var body: some View{
        ScrollView(.vertical){
            VStack(spacing: 25){
                RoundedRectangle(cornerRadius: 30)
                    .fill(.gray.opacity(0.15))
                    .frame(height: 220)
                
                HStack{
                    VStack(alignment: .leading, spacing: 6){
                        Text("Transaction History")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Text("12 Jun 2025 - 20 Sep 2025")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    CustomMenuView(style: .glass) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .frame(width: 40, height: 30)
                    } content: {
                        FilterView()
                    }

                }
            }
            .padding(15)
            .padding(.bottom, 700)
        }
    }
}

//custom filter

struct FilterView: View {

    // MARK: - Slider state
    @State private var lowerLimit: Double = 50
    @State private var upperLimit: Double = 300

    // MARK: - Gender selection state
    enum Gender: Int, CaseIterable {
        case male, female, preferNotToSay
        
        var label: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .preferNotToSay: return "Other"
            }
        }
        
        var color: Color {
            switch self{
                case .male: return .blue
                case .female: return .pink
                case .preferNotToSay: return Color("HauzFocus")
            }
        }
    }
    @State private var selectedGender: Gender = .male

    // MARK: - Gender icons
    private let genderIcons: [Gender: String] = [
        .male: "figure.stand",
        .female: "figure.stand.dress",
        .preferNotToSay: "person.fill.questionmark"
    ]

    var body: some View {
        VStack(spacing: 20) {

            // Title
            Text("Filter Preferences")
                .font(.custom("HooverVariable-Bold_Medium", size: 25))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: - Price Range Section
            VStack(spacing: 12) {
                HStack {
                    Text("Price Range")
                        .font(.custom("HooverVariable-Bold_Regular", size: 15))
                    Spacer()
                }
                
                // Price labels
                HStack {
                    Text("$\(Int(lowerLimit))")
                        .font(.custom("HooverVariable-Bold_Medium", size: 20))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("$\(Int(upperLimit))")
                        .font(.custom("HooverVariable-Bold_Medium", size: 20))
                        .foregroundStyle(.primary)
                }

                // Range slider
                RangeSlider(
                    lowerValue: $lowerLimit,
                    upperValue: $upperLimit,
                    minValue: 0,
                    maxValue: 1000
                )
                .frame(height: 24)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // MARK: - Gender Selection Section
            VStack(spacing: 12) {
                HStack {
                    Text("Gender")
                        .font(.custom("HooverVariable-Bold_Regular", size: 15))
                    Spacer()
                }
                
                // Glass Tab Selector
                HStack(spacing: 0) {
                    ForEach(Gender.allCases, id: \.self) { gender in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedGender = gender
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: genderIcons[gender]!)
                                    .font(.title2)
                                    .foregroundStyle(selectedGender == gender ? .white : .primary)
                                
                                Text(gender.label)
                                    .font(.custom("HooverVariable-Bold_Regular", size: 13))
                                    .fontWeight(selectedGender == gender ? .semibold : .regular)
                                    .foregroundStyle(selectedGender == gender ? .white : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                ZStack {
                                    if selectedGender == gender {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(gender.color)
                                            .shadow(color: gender.color.opacity(0.4), radius: 8, x: 0, y: 4)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            // Apply Button
            Button {
                // Apply filter using lowerLimit, upperLimit, and selectedGender
            } label: {
                Text("Apply Filters")
                    .font(.custom("HooverVariable-Bold_Medium", size: 18))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.glassProminent)
            .tint(Color("HauzFocus"))
            .controlSize(.large)

            // Helper text
            Text("Adjust your preferences and tap Apply to see results")
                .font(.custom("HooverVariable-Bold_Thin", size: 11))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

        }
        .padding(20)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
        )
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}


struct RangeSlider: View {

    // MARK: - Bindings for lower & upper values
    @Binding var lowerValue: Double
    @Binding var upperValue: Double

    // MARK: - Slider range
    let minValue: Double
    let maxValue: Double

    // MARK: - Appearance
    let height: CGFloat = 4
    let thumbSize: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {

                // Background track
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)

                // Active range track
                Capsule()
                    .fill(Color("HauzFocus"))
                    .frame(
                        width: thumbPosition(value: upperValue, width: geo.size.width)
                        - thumbPosition(value: lowerValue, width: geo.size.width),
                        height: height
                    )
                    .offset(x: thumbPosition(value: lowerValue, width: geo.size.width))

                // Lower thumb
                thumb
                    .offset(x: thumbPosition(value: lowerValue, width: geo.size.width) - thumbSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = valueFromDrag(
                                    gesture.location.x,
                                    width: geo.size.width
                                )

                                // Prevent crossing upper value
                                lowerValue = min(max(minValue, newValue), upperValue)
                            }
                    )

                // Upper thumb
                thumb
                    .offset(x: thumbPosition(value: upperValue, width: geo.size.width) - thumbSize / 2)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let newValue = valueFromDrag(
                                    gesture.location.x,
                                    width: geo.size.width
                                )

                                // Prevent crossing lower value
                                upperValue = max(min(maxValue, newValue), lowerValue)
                            }
                    )
            }
        }
        .frame(height: thumbSize)
    }

    // MARK: - Thumb View
    private var thumb: some View {
        Circle()
            .fill(Color.white)
            .frame(width: thumbSize, height: thumbSize)
            .overlay(
                Circle()
                    .stroke(Color("HauzFocus"), lineWidth: 2)
            )
            .shadow(radius: 1)
    }

    // MARK: - Helpers

    /// Converts a slider value into an X position
    private func thumbPosition(value: Double, width: CGFloat) -> CGFloat {
        CGFloat((value - minValue) / (maxValue - minValue)) * width
    }

    /// Converts drag location into a value
    private func valueFromDrag(_ x: CGFloat, width: CGFloat) -> Double {
        let percentage = min(max(0, x / width), 1)
        return minValue + Double(percentage) * (maxValue - minValue)
    }
}

#Preview{
    view()
}

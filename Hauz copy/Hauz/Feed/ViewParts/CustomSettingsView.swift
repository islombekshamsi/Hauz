import SwiftUI

struct SettingsView: View{
    @State private var progress: CGFloat = 0
    var body: some View{
        List{
            Section("Preview"){
                Rectangle()
                    .foregroundStyle(.clear)
                    .background{
                        Image("asics_forpreview")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .contentShape(.rect)
                            .onTapGesture {
                                withAnimation(.bouncy(duration: 0.75, extraBounce: 0.02)){
                                    progress = 0
                                }
                            }
                    }
                    .overlay{
                        ExpandableGlassMenu(alignment: .topLeading, progress: progress) {
                            VStack(alignment: .leading, spacing: 12){
                                RowView("paperplane.fill", "Share", "Let the world know about the app!")
                                RowView("message.badge", "Suggestions", "Let us know how we can improve!")
                                RowView("chart.bar", "Data", "Cool data about your swipes (coming soon!)")
                                RowView("door.left.hand.open", "Log Out", "Please come back soon!")
                            }
                            .padding(10)
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title3)
                                .frame(width: 55, height: 55)
                                .contentShape(.rect)
                                .onTapGesture {
                                    withAnimation(.bouncy(duration: 0.75, extraBounce: 0.02)){
                                        progress = 1
                                    }
                                }
                        }
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .padding(15)

                    }
                    .frame(height: 330)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            
            Section("Properties"){
                Slider(value: $progress)
            }
        }

    }
    // Settings button presentation
    
    @ViewBuilder
    func RowView(_ image: String, _ title: String, _ description: String) -> some View{
        Button {
            
        } label: {
            HStack(spacing: 10){
                Image(systemName: image)
                    .foregroundStyle(Color("HauzFocus"))
                    .font(.title3)
                    .symbolVariant(.fill)
                    .frame(width: 45, height: 45)
                    .background(.background, in: .circle)
                
                VStack(alignment: .leading, spacing: 3){
                    Text(title)
                        .foregroundStyle(Color("HauzFocus"))
                        .font(.custom("HooverVariable-Bold", size: 20))
                    
                    Text(description)
                        .foregroundStyle(Color("HauzFocus"))
                        .font(.custom("HooverVariable-Bold_Regular", size: 14))

                        .lineLimit(2)
                }
            }
            .padding(10)
            .contentShape(.rect)
        }

    }
}

struct ExpandableGlassMenu<Content: View, Label: View>: View, Animatable{
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    
    @State private var contentSize: CGSize = .zero
    
    var animatableData: CGFloat{
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View{
        GlassEffectContainer{
            let widthDiff = contentSize.width - labelSize.width
            let heightDiff = contentSize.height - labelSize.height
            
            let rWidth = widthDiff * contentOpacity
            let rHeight = heightDiff * contentOpacity
            
            ZStack(alignment: alignment) {
                content
                    .compositingGroup()
                    .scaleEffect(contentScale)
                    .blur(radius: 14 * blurProgress)
                    .opacity(contentOpacity)
                    .onGeometryChange(for: CGSize.self){
                        $0.size
                    } action: {newValue in
                        contentSize = newValue
                    }
                    .fixedSize()
                    .frame(
                        width: labelSize.width + rWidth,
                        height: labelSize.height + rHeight)
                
                label
                    .compositingGroup()
                    .blur(radius: 14 * blurProgress)
                    .opacity(1-labelOpacity)
                    .frame(width: labelSize.width, height: labelSize.height)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: cornerRadius))
            
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
        .scaleEffect(
            x: 1 - (blurProgress * 0.35),
            y: 1 + (blurProgress * 0.45),
            anchor: scaleAnchor
        )
        .offset(y: -75 * blurProgress)
    }
    
    var labelOpacity: CGFloat{
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat{
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat{
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    var blurProgress: CGFloat{
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    var offset: CGFloat{
        switch alignment{
            case .bottom, .bottomLeading, .bottomTrailing: return -75
            case .top, .topTrailing, .topLeading: return 75
            default: return 0
        }
    }
    
    
    var scaleAnchor: UnitPoint{
        switch alignment{
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
        
    }
}





#Preview{
    SettingsView()
}

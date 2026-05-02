import SwiftUI

extension View{
    @ViewBuilder
    func borderBeam(
        border: Color,
        hideFadeBorder: Bool = true,
        beam: [Color],
        beamBlur: CGFloat,
        cornerRadius: CGFloat,
        isEnabled: Bool = true
    ) -> some View{
        self
            .modifier(BorderBeamEffect(
                border: border,
                hideFadeBorder: hideFadeBorder,
                beam: beam,
                beamBlur: beamBlur,
                cornerRadius: cornerRadius,
                isEnabled: isEnabled))
    }
}

struct BorderBeamEffect: ViewModifier {
    var border: Color
    var hideFadeBorder: Bool
    var beam: [Color]
    var beamBlur: CGFloat
    var cornerRadius: CGFloat
    var isEnabled: Bool
    func body(content: Content) -> some View {
        content
            .background{
            
                if isEnabled{
                    BorderBeanView()
                }
            }
    }
    @ViewBuilder
    private func BorderBeanView() -> some View {
        ZStack{
            if !hideFadeBorder{
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(border.tertiary, lineWidth: 0.6)
            }
            KeyframeAnimator(initialValue: 0.0, repeating: true) { value in
                let rotation = value * 360
                
                let borderGradient = AngularGradient(colors:[.clear, border, .clear] ,
                    center: .center,
                    startAngle: .degrees(140 + rotation),
                    endAngle: .degrees(270 + rotation)
                )
                let beamGradient = LinearGradient(
                    colors: beam,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // beam gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(beamGradient)
                    .mask{
                        Rectangle()
                            .overlay{
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .blur(radius: beamBlur)
                                    .blendMode(.destinationOut)
                            }
                    }
                    .mask{
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(borderGradient)
                            .blur(radius: beamBlur / 1.5)
                            .padding(-beamBlur * 2)
                    }
                
                //border gradient
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderGradient, lineWidth: 0.6)
            } keyframes: { _ in
                LinearKeyframe(1, duration: 2.5)
            }
        }
        .padding(0.5)
    }
}

#Preview {
    struct PreviewHolder: View {
        @State private var text = ""
        var body: some View {
            BorderContentView(text: $text, onDismiss: {})
        }
    }
    return PreviewHolder()
}

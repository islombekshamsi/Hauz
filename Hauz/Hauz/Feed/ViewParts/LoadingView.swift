import SwiftUI

struct LoadingView: View {
    let text = Array("Hauz")
    
    var body: some View {
        Color.white.ignoresSafeArea(edges: .all)
        HStack(spacing: 4) {
            ForEach(text.indices, id: \.self) { index in
                WavingLetter(
                    letter: String(text[index]),
                    index: index
                )
            }
        }
    }
}

struct WavingLetter: View {
    let letter: String
    let index: Int
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        Text(letter)
            .foregroundStyle(Color("HauzFocus"))
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1)
                ) {
                    offset = -15
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        LoadingView()
            .foregroundColor(.white)
    }
}

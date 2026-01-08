import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        NavigationStack{
            ScrollView(.vertical, content: {
                VStack{
                    ForEach(1...100, id: \.self){_ in
                        Rectangle()
                            .fill(.black)
                            .frame(height: 320)
                            .swipeActions{
                                Action(symbolImage: "square.and.arrow.up.fill", tint: .white, background: .blue) { resetPosition in
                                    resetPosition.toggle()
                                }
                                
                                // 🔥 DELETE BUTTON - Swipe more to see it expand like a bubble!
                                Action(symbolImage: "trash.fill", tint: .white, background: .red) { resetPosition in
                                    // Delete action
                                    resetPosition.toggle()
                                }
                            }
                    }
                }
                .padding(15)
            })
            .navigationTitle("Custom Swipe Actions")
        }
    }
}

#Preview {
    SwiftUIView()
}

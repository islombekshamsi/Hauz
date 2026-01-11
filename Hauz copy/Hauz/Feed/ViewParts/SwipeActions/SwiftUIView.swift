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
                                
                                // 🔥 DELETE BUTTON - Swipe more to see it expand like a bubble!
                                Action(symbolImage: "trash.fill", tint: Color("HauzBg"), background: Color("HauzFocus")) { resetPosition in
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

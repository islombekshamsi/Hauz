import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        NavigationStack{
            ScrollView(.vertical, content: {
                VStack{
                    ForEach(1...100, id: \.self){_ in
                        Rectangle()
                            .fill(.black)
                            .frame(height: 50)
                            .swipeActions{
                                Action(symbolImage: "square.and.arrow.up.fill", tint: .white, background: .blue) { resetPosition in
                                    resetPosition.toggle()
                                }
                                
                                Action(symbolImage: "square.and.arrow.down.fill", tint: .white, background: .purple) { resetPosition in
                                    
                                }
                                
                                Action(symbolImage: "trash.fill", tint: .white, background: .red) { resetPosition in
                                    
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

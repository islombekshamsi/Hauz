import SwiftUI


struct HauzFilterView: View{
    var options: [String] = ["Everything", "Trending"]
    @Binding  var selection: String
    @Namespace private var namespace
    var body: some View{
        HStack(alignment: .top, spacing: 32){
            ForEach(options, id: \.self){option in
                VStack{
                    Text(option)
                        .frame(maxWidth: .infinity)
                        .font(.custom("HooverVariable-Bold_Light", size: 16))
                        .bold()

                    if selection == option{
                        RoundedRectangle(cornerRadius: 2)
                            .frame(height: 1.5)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                .padding(.top, 8)
                .background(Color.black.opacity(0.001))
                .foregroundStyle(selection == option ? Color("HauzLight") : Color("HauzBg").opacity(0.3))
                .onTapGesture {
                    selection = option
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color("HauzFocus"))
        .animation(.smooth, value: selection)
    }
}

fileprivate struct HauzFilterView_Previews: View {
    var options: [String] = ["Everyone", "Special" ,"Trending"]
    @State private var selection = "Everyone"
    var body: some View{
        HauzFilterView(options: options, selection: $selection)
    }
}


#Preview {
    HauzFilterView_Previews()
        .padding()
}


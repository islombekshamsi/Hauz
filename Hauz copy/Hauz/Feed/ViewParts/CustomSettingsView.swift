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
                    }
                    .overlay{
                        ExpandableGlassMenu(alignment: .bottomTrailing, progress: progress) {
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
                        }

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
                    .font(.title3)
                    .symbolVariant(.fill)
                    .frame(width: 45, height: 45)
                    .background(.background, in: .circle)
                
                VStack(alignment: .leading, spacing: 6){
                    Text(title)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }
            }
            .padding(10)
            .contentShape(.rect)
        }

    }
}

struct ExpandableGlassMenu<Content: View, Label: View>: View{
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    var body: some View{
        
    }
}





#Preview{
    SettingsView()
}

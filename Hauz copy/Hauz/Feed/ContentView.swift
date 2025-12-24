import SwiftUI

enum CustomTab: String, CaseIterable{
    case feed = "Feed"
    case profile = "Profile"
    
    var symbol: String{
        switch self{
            case .feed: return "hanger"
            case .profile: return "person.crop.circle"
        }
    }
    
    var actionSymbol: String{
        switch self{
        case .feed: return "slider.horizontal.3"
        case .profile: return "gearshape"
        }
    }
    
    var index: Int{
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

struct ContentView: View {
    @State private var activeTab: CustomTab = .feed
    var body: some View {
        TabView(selection: $activeTab){
            Tab.init(value: .feed){
                MainView()
                .toolbarVisibility(.hidden, for: .tabBar)
            }
            Tab.init(value: .profile){
                ProfileView()
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0){
            CustomTabBarView()
                .padding(.horizontal, 20)
        }
    }
    
    @ViewBuilder
    
    func CustomTabBarView() -> some View{
        GlassEffectContainer(spacing: 10){
            HStack(spacing: 10){
                GeometryReader{
                    CustomTabBar(size: $0.size, activeTab: $activeTab){ tab in
                        VStack(spacing: 3){
                            Image(systemName: tab.symbol)
                                .font(.title2)
                            
                            Text(tab.rawValue)
                                .font(.custom("HooverVariable-Bold_Regular", size: 12))
                                .fontWeight(tab == self.activeTab ? .bold : .regular)
                                
                        }
                        .symbolVariant(.fill)
                        .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
                
                ZStack{
                    ForEach(CustomTab.allCases, id: \.rawValue){ tab in
                        Image(systemName: tab.actionSymbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color("HauzFocus"))
                            .blurFade(activeTab == tab)
                    }
                }
                .frame(width: 55, height: 55)
                .glassEffect(.regular.interactive(), in: .capsule)
                .animation(.smooth(duration: 0.4, extraBounce: 0), value: activeTab)
                
            }
        }
        .frame(height: 55)
    }
}

extension View{
    @ViewBuilder
    
    func blurFade(_ status: Bool)-> some View{
        self
            .compositingGroup()
            .blur(radius: status ? 0 : 10)
            .opacity(status ? 1 : 0)
    }
    
}

#Preview{
    ContentView()
}

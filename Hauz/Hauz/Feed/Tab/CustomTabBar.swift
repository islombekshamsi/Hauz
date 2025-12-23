//
//  CustomTabBar.swift
//  Hauz
//
//  Created by Islom Shamsiev on 2025/12/21.
//

import SwiftUI

struct CustomTabBar<TabItemView: View>:UIViewRepresentable {
    var size: CGSize
    var activeTint: Color = Color("HauzLight") // change the color to hauz colors
    var barTint: Color = Color("HauzFocus").opacity(0.8)
    @Binding var activeTab: CustomTab
    @ViewBuilder var tabItemView: (CustomTab) -> TabItemView
    
    func makeCoordinator() -> Coordinator{
        Coordinator(parent: self)
    }
    
    func makeUIView(context: Context) -> some UIView {
        let items = CustomTab.allCases.map(\.rawValue)
        let control = UISegmentedControl(items: items)
        
        for (index, tab) in CustomTab.allCases.enumerated(){
            let renderer = ImageRenderer(content: tabItemView(tab))
            
            renderer.scale = 2
            let image = renderer.uiImage
            
            control.setImage(image, forSegmentAt: index)
        }
        
        
        DispatchQueue.main.async {
            for subview in control.subviews{
                if subview is UIImageView && subview != control.subviews.last{
                    subview.alpha = 0
                }
            }
        }
        
        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(activeTint)
        ], for: .selected)
        
        control.selectedSegmentIndex = 0
        control.addTarget(context.coordinator, action: #selector(context.coordinator.tabSelected(_:)), for:.valueChanged)
        return control
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context){
        
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIViewType, context: Context) -> CGSize? {
        return size
    }
    
    class Coordinator: NSObject{
        var parent: CustomTabBar
        init(parent: CustomTabBar){
            self.parent = parent
        }
        
        @objc func tabSelected(_ sender: UISegmentedControl){
            parent.activeTab = CustomTab.allCases[sender.selectedSegmentIndex]
        }
    }
}

#Preview {
    ContentView()
}

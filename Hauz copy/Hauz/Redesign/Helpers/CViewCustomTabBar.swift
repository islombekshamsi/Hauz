import SwiftUI

struct CViewCustomTabBar<TabItemView: View>: UIViewRepresentable {
    var size: CGSize
    var activeTint: Color = Color("HauzLight")
    var barTint: Color = Color("HauzFocus").opacity(0.8)
    @Binding var activeTab: CViewTab
    @ViewBuilder var tabItemView: (CViewTab) -> TabItemView

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> some UIView {
        let items = CViewTab.allCases.map(\.rawValue)
        let control = UISegmentedControl(items: items)

        for (index, tab) in CViewTab.allCases.enumerated() {
            let renderer = ImageRenderer(content: tabItemView(tab))
            renderer.scale = 2
            let image = renderer.uiImage
            control.setImage(image, forSegmentAt: index)
        }

        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        control.selectedSegmentTintColor = UIColor(barTint)
        control.setTitleTextAttributes([
            .foregroundColor: UIColor(activeTint),
        ], for: .selected)

        control.selectedSegmentIndex = CViewTab.allCases.firstIndex(of: activeTab) ?? 0
        control.addTarget(
            context.coordinator,
            action: #selector(Coordinator.tabSelected(_:)),
            for: .valueChanged
        )
        return control
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {
        guard let control = uiView as? UISegmentedControl else { return }
        let desiredIndex = CViewTab.allCases.firstIndex(of: activeTab) ?? 0
        if control.selectedSegmentIndex != desiredIndex {
            control.selectedSegmentIndex = desiredIndex
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIViewType, context: Context) -> CGSize? {
        return size
    }

    final class Coordinator: NSObject {
        var parent: CViewCustomTabBar
        init(parent: CViewCustomTabBar) {
            self.parent = parent
        }

        @objc func tabSelected(_ sender: UISegmentedControl) {
            parent.activeTab = CViewTab.allCases[sender.selectedSegmentIndex]
        }
    }
}

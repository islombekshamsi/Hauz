import SwiftUI

struct InfiniteScrollView<Content: View>: View {
    var spacing: CGFloat = 10
    @ViewBuilder var content: Content
    @State private var contentSize: CGSize = .zero
    var body: some View {
        GeometryReader{
            let size = $0.size
        ScrollView(.horizontal){
            HStack(spacing: spacing){
                Group(subviews: content){collection in
                    HStack(spacing: spacing){
                        ForEach(collection){view in
                            view
                            
                        }
                    }
                    .onGeometryChange(for: CGSize.self){
                        $0.size
                    } action: {newValue in
                        contentSize = .init(width: newValue.width + spacing, height: newValue.height)
                        
                    }
                    
                    let averageWidth = contentSize.width/CGFloat(collection.count)
                    let repeatingCount = contentSize.width > 0 ? Int((size.width/averageWidth).rounded()) + 1 : 1
                    
                    HStack(spacing: spacing){
                        ForEach(0..<repeatingCount, id: \.self){index in
                            let view = Array(collection)[index % collection.count]
                            
                            view
                        }
                    }
                    
                    
                }
            }
        }
    }
    }
}

#Preview{
    PreviewOutlook()
}

fileprivate struct InfiniteScrollHelper: UIViewRepresentable{
    @Binding var contentSize: CGSize
    @Binding var declarationRate: UIScrollView.DecelerationRate
    
    func makeCoordinator() -> Coordinator {
        Coordinator(declarationRate: declarationRate, contentSize: contentSize)
    }
    func makeUIView(context: Context) -> some UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        DispatchQueue.main.async{
            if let scrollView = view.scrollView{
                
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        context.coordinator.declarationRate = declarationRate
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate{
        var declarationRate: UIScrollView.DecelerationRate
        var contentSize: CGSize
        
        init(declarationRate: UIScrollView.DecelerationRate, contentSize: CGSize) {
            self.declarationRate = declarationRate
            self.contentSize = contentSize
        }
        
        weak var defaultDelegate: UIScrollViewDelegate?
        
        func scrollViewDidScroll(_ scrollView: UIScrollView){
            
        }
    }
}

extension UIView{
    var scrollView: UIScrollView?{
        if let superview, superview is UIScrollView{
            return superview as? UIScrollView
        }
        return superview?.scrollView
    }
}

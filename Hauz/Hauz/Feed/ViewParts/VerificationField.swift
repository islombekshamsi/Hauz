import SwiftUI

enum CodeType: Int, CaseIterable{
    case four = 4
    case six = 6
    
    var stringValue: String{
        "\(rawValue) Digit"
    }
}


enum TypingState{
    case typing
    case valid
    case invalid
}

enum TextFieldStyle: String, CaseIterable{
    case roundedBorder = "Rounded Border"
    case underlined = "underlined"
}


struct VerificationField: View{
    var type: CodeType
    var style: TextFieldStyle = .roundedBorder
    @Binding var value: String
    
    var onChange: (String) async -> TypingState
    
    @State private var state: TypingState = .typing
    @FocusState private var isActive: Bool
    @State private var invalidTrigger: Bool = false
    var body: some View{
        HStack(spacing: style == .roundedBorder ? 6 : 10){
            ForEach(0..<type.rawValue, id: \.self){index in
                CharacterView(index)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: value)
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .compositingGroup()
        .phaseAnimator([0,10,-10,10,-5,5,0], trigger: invalidTrigger, content: {
            content, offset in
            
            content
                .offset(x: offset)
        }, animation: {_ in
                .linear(duration: 0.06)
            
        })
        .background{
            TextField("", text: $value)
                .focused($isActive)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .mask(alignment: .trailing){
                    Rectangle()
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                }
                .allowsHitTesting(false)
        }
        .contentShape(.rect)
        .onTapGesture{
            isActive = true
        }
        
        .onChange(of: value){oldValue, newValue in
            value = String(newValue.prefix(type.rawValue))
            Task{ @MainActor in
                state = await onChange(value)
                if state == .invalid{
                    invalidTrigger.toggle()
                }
            }
            
        }
        
        
    }
    
    @ViewBuilder
    func CharacterView(_ index: Int) -> some View{
        Group{
            if style == .roundedBorder{
                RoundedRectangle(cornerRadius: 15)
                    .stroke(borderColor(index), lineWidth: 2)
            } else {
                Rectangle()
                    .fill(borderColor(index))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .frame(width: style == .roundedBorder ? 50: 40, height: 50)
        .overlay{
            let stringValue = string(index)
            
            if stringValue != ""{
                Text(stringValue)
                    .font(.custom("HooverVariable-Bold_Regular", size: 25))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("HauzFocus"))
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func string(_ index: Int) -> String{
        if value.count > index{
            let startIndex = value.startIndex
            let stringIndex = value.index(startIndex, offsetBy: index)
            
            return String(value[stringIndex])
        }
        
        return ""
    }
    
    func borderColor(_ index: Int) -> Color{
        switch state{
        case .typing: value.count == index && isActive ? Color.primary: .secondary
        case .valid: .green
        case .invalid: .red
        }
    }
}

struct viewTheCode: View{
    @State private var code: String = ""
    var body: some View{
        VerificationField(type: .six, style: .roundedBorder, value: $code){result in
            if result.count < 6{
                return .typing
            } else if result == "123456"{
                return .valid
            } else {
                return .invalid
            }
            
        }
    }
}


#Preview{
    viewTheCode()
}

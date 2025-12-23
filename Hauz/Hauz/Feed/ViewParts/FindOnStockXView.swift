//
//  FindOnStockXView.swift
//  Shoesly
//
//  Created by Islom Shamsiev on 2025/11/24.
//

import SwiftUI

struct FindOnStockXView: View {
    @State var stockXGreen: Color = Color(red: 0/255, green: 99/255, blue: 64/255)
    @State var stockXWhite: Color = Color(red: 245/255, green: 245/255, blue: 245/255)
    var body: some View {
        ZStack{
            RoundedRectangle(cornerRadius: 30)
                .frame(width:300, height:60)
                .foregroundStyle(stockXGreen)
                .overlay(
                    HStack(spacing: 3){
                        Text("Find on")
                            .font(.system(size: 20,weight: .semibold ,design: .rounded))
                            .foregroundColor(stockXWhite)
                        Image("stockxlogo")
                            .resizable()
                            .frame(width: 80, height: 55)
                    }
                )
                
        }
    }
}

#Preview {
    FindOnStockXView()
}

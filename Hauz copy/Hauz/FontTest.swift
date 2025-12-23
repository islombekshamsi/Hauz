//
//  FontTest.swift
//  Hauz
//
//  Created by Islom Shamsiev on 2025/12/22.
//

import SwiftUI

struct FontTest: View {
    var body: some View {
        Text("Hello, World!")
            .font(.custom("HooverVariable-Bold_Regular", size: 30))
        
    }
    
    init(){
        for familyName in UIFont.familyNames{
            print(familyName)
            
            for fontName in UIFont.fontNames(forFamilyName: familyName){
                print("-- \(fontName)")
            }
        }
    }
}

#Preview {
    FontTest()
}

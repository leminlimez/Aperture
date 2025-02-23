//
//  SettingsView.swift
//  Da Moon
//
//  Created by lemin on 2/23/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Variables
    @AppStorage("useLocalOnly") var useLocalOnly: Bool = false
    @AppStorage("useDarkenedBG") var useDarkenedBG: Bool = true
    @AppStorage("darknessValue") var darknessValue: Double = 0.3
    
    var body: some View {
        ScrollView {
            HStack {
                Text("Settings")
                    .font(.custom("Courier-Bold", size: 60)) // scale the text
                    .fontWeight(.heavy)
                    .minimumScaleFactor(0.1)
                    .scaledToFit()
                    .lineLimit(1)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                }
                .foregroundStyle(.primary)
            }
            .padding(.horizontal, 15)
            .padding(.top, 15)
            Group {
                Toggle("Use Local Only", systemImage: "server.rack", isOn: $useLocalOnly)
                Toggle("Use Darkened Background on Cutout", systemImage: "fluid.transmission", isOn: $useDarkenedBG)
                VStack {
                    HStack {
                        Label("Separated Background Brightness", systemImage: "sun.max")
                        Spacer()
                        Text("\(Int(darknessValue * 100))%")
                    }
                    .padding(.top, 5)
                    Slider(value: $darknessValue, in: 0.0...1.0, step: 0.05, label: {
                        Text("")
                    }, minimumValueLabel: {
                        Text("0%")
                    }, maximumValueLabel: {
                        Text("100%")
                    })
                }
                .scaleEffect(useDarkenedBG ? 1.0 : 0.0)
                .transition(.scale)
                .animation(.easeOut, value: useDarkenedBG)
            }.padding(.horizontal, 10)
        }
    }
}

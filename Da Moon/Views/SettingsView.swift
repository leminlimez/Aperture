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
            }.padding(.horizontal, 10)
        }
    }
}

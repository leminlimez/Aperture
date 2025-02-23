//
//  ButtonStyles.swift
//  Da Moon
//
//  Created by lemin on 2/23/25.
//

import SwiftUI

struct MainMenuButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var color: Color
    var cornerRadius: CGFloat = 14
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .foregroundStyle(color)
            }
            .shadow(color: color, radius: 13)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

struct ToolbarItemStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var color: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .shadow(radius: 5)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

//
//  GlossyShine.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

let GLOSS_DURATION: Double = 1.5

extension View {
    @ViewBuilder
    func shine(_ toggle: Bool) -> some View {
        self
            .overlay {
                ShineView(toggle: toggle)
            }
    }
}

struct ShineView: View {
    var toggle: Bool
    
    @State private var triggered: Bool = false
    @State private var timer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            Rectangle()
                .fill(.linearGradient(
                    colors: [
                        .clear,
                        .clear,
                        .white.opacity(0.1),
                        .white.opacity(0.5),
                        .white,
                        .white.opacity(0.5),
                        .white.opacity(0.1),
                        .clear,
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .scaleEffect(y: 8)
                .offset(x: -size.width / 2)
                .keyframeAnimator(initialValue: 0.0, trigger: triggered, content: { content, progress in
                    content
                        .offset(x: (2.0 * -size.width / 3.0) + (progress * size.width * 3))
                }, keyframes: { _ in
                    CubicKeyframe(.zero, duration: 0.05)
                    CubicKeyframe(1, duration: GLOSS_DURATION)
                })
                .animation(.linear(duration: GLOSS_DURATION).repeatForever(autoreverses: false), value: toggle)
                .rotationEffect(.degrees(45))
                .opacity(toggle ? 1 : 0)
                .onChange(of: toggle, initial: true) {
                    if toggle {
                        triggered = true
                        startRepeatingAnimation()
                    } else {
                        timer?.invalidate()
                        triggered = false
                    }
                }
        }
        .clipShape(Rectangle())
    }
    
    func startRepeatingAnimation() {
        // Invalidate previous timer, if any
        timer?.invalidate()
        
        // Set a new repeating timer
        timer = Timer.scheduledTimer(withTimeInterval: GLOSS_DURATION + 0.1, repeats: true) { _ in
            // Toggle the animation trigger every time the timer fires
            triggered.toggle()
        }
    }
}

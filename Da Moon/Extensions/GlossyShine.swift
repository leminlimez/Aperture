//
//  GlossyShine.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

extension View {
    @ViewBuilder
    func shine(_ toggle: Bool) -> some View {
        self
            .overlay {
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
                        .keyframeAnimator(initialValue: 0.0, trigger: toggle, content: { content, progress in
                            content
                                .offset(x: -size.width / 2 + (progress * size.width))
                        }, keyframes: { _ in
                            CubicKeyframe(.zero, duration: 0.1)
                            CubicKeyframe(1, duration: 0.5)
                        })
                        .rotationEffect(.degrees(45))
                        .opacity(toggle ? 1 : 0)
                }
                .clipShape(Rectangle())
            }
    }
}

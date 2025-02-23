//
//  ImageSaveAnim.swift
//  Da Moon
//
//  Created by lemin on 2/23/25.
//

import SwiftUI

let SAVE_GROW_DURATION: Double = 0.3
let SAVE_HANG_DURATION: Double = 0.1
let SAVE_SHRINK_DURATION: Double = 0.7
let SAVE_ANIM_DURATION: Double = SAVE_GROW_DURATION + SAVE_HANG_DURATION + SAVE_SHRINK_DURATION

extension View {
    @ViewBuilder
    func saveAnimation(_ toggle: Bool, startOffset: CGFloat, imgSize: CGSize) -> some View {
        self
            .keyframeAnimator(initialValue: 0.0, trigger: toggle, content: { content, progress in
                content
                    .scaleEffect(1.0 - progress)
                    .offset(
                        y: progress * ((imgSize.height / 2) + startOffset)
                    )
            }, keyframes: { _ in
                CubicKeyframe(.zero, duration: 0.05)
                LinearKeyframe(-0.07, duration: SAVE_GROW_DURATION, timingCurve: .circularEaseOut)
                LinearKeyframe(1, duration: SAVE_SHRINK_DURATION, timingCurve: .circularEaseIn)
            })
            .opacity(toggle ? 1 : 0)
    }
}

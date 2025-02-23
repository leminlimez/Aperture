//
//  CameraButtonView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

struct CaptureButtonView: View {
    let circle_size: CGFloat = 80
    let outer_offset: CGFloat = 12
    let outer_width: CGFloat = 5
    
    @Binding var playShutter: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .foregroundStyle(Color.white)
                .frame(width: circle_size, height: circle_size)
                .opacity(playShutter ? 0 : 1) // play shutter on only the inner circle
                .animation(.easeOut(duration: ShutterDuration))
            Circle()
                .stroke(.white, lineWidth: outer_width)
                .foregroundStyle(Color.clear)
                .frame(width: circle_size + outer_offset, height: circle_size + outer_offset)
        }
    }
}

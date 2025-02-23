//
//  ResultsView.swift
//  Da Moon
//
//  Created by lemin on 2/22/25.
//

import SwiftUI

enum OverlayMode: String, CaseIterable {
    case SideBySide = "Side-by-Side"
    case Overlay = "Overlay"
}

let DRAGGABLE_CIRCLE_SIZE: CGFloat = 30

struct ResultsView: View {
    // Images
    var originalImage: UIImage
    var upscaledImage: UIImage
    
    // Overlay
    @State private var currentMode: OverlayMode = .SideBySide
    @State private var opacity: Double = 1.0
    @State private var sideAmount: Double = 0.5
    
    @State private var imageSize: CGSize = .zero
    @State private var imageMinX: CGFloat = 0.0
    @State private var imageMinY: CGFloat = 0.0
    
    // Animations
    @State private var playSaveAnimation: Bool = false
    
    var body: some View {
        VStack {
            ZoomableView {
                ZStack {
                    Image(uiImage: originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay {
                            GeometryReader { geometry in
                                Image(uiImage: upscaledImage)
                                    .resizable()
                                    .foregroundStyle(.blue)
                                    .aspectRatio(contentMode: .fit)
                                    .opacity(currentMode == .Overlay ? opacity : 1.0)
                                    .transition(.opacity)
                                    .animation(.easeOut, value: currentMode == .SideBySide)
                                    .onChange(of: geometry.size, initial: true) {
                                        imageSize = geometry.size
                                    }
                                    .onChange(of: geometry.frame(in: .local).minX, initial: true) {
                                        imageMinX = geometry.frame(in: .local).minX
                                    }
                                    .onChange(of: geometry.frame(in: .global).minY, initial: true) {
                                        imageMinY = geometry.frame(in: .global).minY
                                    }
                                    .overlay {
                                        let rectWidth = currentMode == .SideBySide ? imageSize.width * sideAmount : imageSize.width
                                        Rectangle()
                                            .fill(.black)
                                            .blendMode(.destinationOut)
                                            .opacity(currentMode == .SideBySide ? 1.0 : 0.0)
                                            .frame(width: rectWidth)
                                            .frame(maxHeight: .infinity)
                                            .offset(x: (-imageSize.width / 2) + (rectWidth / 2))
                                            .transition(.slide.combined(with: .opacity))
                                            .animation(.easeOut, value: currentMode == .SideBySide)
                                    }
                                    .compositingGroup()
                            }
                        }
                        .overlay {
                            ZStack {
                                Rectangle()
                                    .frame(maxWidth: 4, maxHeight: .infinity)
                                    .foregroundStyle(.white)
                                Circle()
                                    .frame(width: DRAGGABLE_CIRCLE_SIZE, height: DRAGGABLE_CIRCLE_SIZE)
                                    .foregroundStyle(.white)
                                Image(systemName: "arrow.left.arrow.right")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.black)
                                    .frame(width: DRAGGABLE_CIRCLE_SIZE - 10, height: DRAGGABLE_CIRCLE_SIZE - 10)
                            }
                            .offset(x: currentMode == .SideBySide ? (-imageSize.width / 2) + (imageSize.width * sideAmount) : imageSize.width / 2)
                            .shadow(radius: 10)
                            .opacity(currentMode == .SideBySide ? 1.0 : 0.0)
                            .transition(.slide.combined(with: .opacity))
                            .animation(.easeOut, value: currentMode == .SideBySide)
                            .simultaneousGesture(
                                DragGesture(minimumDistance: 0.0)
                                    .onChanged { drag in
                                        guard currentMode == .SideBySide else { return }
                                        let pos = drag.location.x + imageSize.width / 2 - DRAGGABLE_CIRCLE_SIZE / 2
                                        if pos < imageMinX {
                                            sideAmount = 0.0
                                        } else if pos > imageMinX + imageSize.width {
                                            sideAmount = 1.0
                                        } else {
                                            sideAmount = (pos - imageMinX) / imageSize.width
                                        }
                                    }
                            )
                        }
                    
                    // MARK: Animation-Specific Image
                    Image(uiImage: upscaledImage)
                        .resizable()
                        .scaledToFit()
                        .saveAnimation(playSaveAnimation, startOffset: imageMinY, imgSize: imageSize)
                }
                
                .padding(.horizontal, 10)
            }
            // MARK: Bottom Bar
            HStack {
                // Choose Mode
                Picker("Mode", selection: $currentMode) {
                    ForEach(OverlayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 190)
                // Slider if overlay
                if currentMode == .Overlay {
                    Spacer()
                    Slider(value: $opacity, in: 0.0...1.0)
                }
            }
            .transition(.slide)
            .animation(.bouncy, value: currentMode != .Overlay)
            .frame(maxWidth: .infinity, maxHeight: 50)
            .padding(.top, 4)
            .padding(.horizontal, 10)
            .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    HStack {
                        // MARK: Save Photo
                        Button(action: {
                            UIImageWriteToSavedPhotosAlbum(upscaledImage, nil, nil, nil)
                            playSaveAnimation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + SAVE_ANIM_DURATION) {
                                playSaveAnimation = false
                                UIApplication.shared.alert(title: "Photo Saved", body: "The upscaled image has been saved to your Photo Library.")
                            }
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        
                        // MARK: Share Upscaled Photo
                        let upscaled = Image(uiImage: upscaledImage)
                        ShareLink(item: upscaled, preview: SharePreview("Upscaled Result", image: upscaled)) {
                            Image(systemName: "square.and.arrow.up")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                }
            }
        }
    }
}

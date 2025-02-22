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
    
    @State private var imageWidth: CGFloat = 0.0
    @State private var imageMinX: CGFloat = 0.0
    
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
                                    .onChange(of: geometry.size.width, initial: true) {
                                        imageWidth = geometry.size.width
                                    }
                                    .onChange(of: geometry.frame(in: .local).minX, initial: true) {
                                        imageMinX = geometry.frame(in: .local).minX
                                    }
                                    .overlay {
                                        let rectWidth = currentMode == .SideBySide ? imageWidth * sideAmount : imageWidth
                                        Rectangle()
                                            .fill(.black)
                                            .blendMode(.destinationOut)
                                            .opacity(currentMode == .SideBySide ? 1.0 : 0.0)
                                            .frame(width: rectWidth)
                                            .frame(maxHeight: .infinity)
                                            .offset(x: (-imageWidth / 2) + (rectWidth / 2))
                                            .transition(.slide.combined(with: .opacity))
                                            .animation(.easeOut, value: currentMode == .SideBySide)
                                    }
                                    .compositingGroup()
                            }
                        }
                    
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
                    .shadow(radius: 10)
                    .offset(x: currentMode == .SideBySide ? (-imageWidth / 2) + (imageWidth * sideAmount) : imageWidth / 2)
                    .opacity(currentMode == .SideBySide ? 1.0 : 0.0)
                    .transition(.slide.combined(with: .opacity))
                    .animation(.easeOut, value: currentMode == .SideBySide)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0.0)
                            .onChanged { drag in
                                guard currentMode == .SideBySide else { return }
                                let pos = drag.location.x + imageWidth / 2 - DRAGGABLE_CIRCLE_SIZE / 2
                                if pos < imageMinX {
                                    sideAmount = 0.0
                                } else if pos > imageMinX + imageWidth {
                                    sideAmount = 1.0
                                } else {
                                    sideAmount = (pos - imageMinX) / imageWidth
                                }
                            }
                    )
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
                    Button(action: {
                        // TODO: Save Photo
                    }) {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
    }
}

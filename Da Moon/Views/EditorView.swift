//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

let BOTTOM_BAR_PADDING: CGFloat = 18

struct EditorView: View {
    @Binding var image: UIImage?
    
    var body: some View {
        ZStack {
            if let image = image {
                ZoomableView {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button(action: {
                                    // TODO: Finalize and Upscale button
                                }) {
                                    Image(systemName: "photo.badge.checkmark")
                                }
                            }
                        }
                }
            }
            VStack {
                Spacer()
                // MARK: Bottom Bar
                HStack {
                    Button(action: {
                        // TODO: Lasso Tool
                    }) {
                        Image(systemName: "lasso")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // TODO: Select bounding box tool
                    }) {
                        Image(systemName: "rectangle.dashed")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // TODO: Select Subject
                    }) {
                        Image(systemName: "person.and.background.dotted")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                    Button(action: {
                        // TODO: Upscale Text
                    }) {
                        Image(systemName: "character.magnify")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    .padding(.horizontal, BOTTOM_BAR_PADDING)
                }
                .frame(maxWidth: .infinity, maxHeight: 40)
                .padding(.bottom, 10)
                .padding(.top, 20)
                .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
            }
        }
    }
}

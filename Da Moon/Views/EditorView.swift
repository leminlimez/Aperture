//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

let BOTTOM_BAR_PADDING: CGFloat = 15

struct EditorView: View {
    @Binding var image: UIImage?
    
    var body: some View {
        VStack {
            Spacer()
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 30)
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
            .frame(maxHeight: 40)
            .padding(.vertical, 10)
        }
    }
}

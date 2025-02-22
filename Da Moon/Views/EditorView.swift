//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import NavigationTransitions

struct EditorView: View {
    @Binding var image: UIImage?
    
    var body: some View {
        VStack {
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
                        
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button(action: {
                                // TODO: Lasso Tool
                            }) {
                                Image(systemName: "lasso")
                            }
                            Button(action: {
                                // TODO: Select bounding box tool
                            }) {
                                Image(systemName: "rectangle.dashed")
                            }
                            Button(action: {
                                // TODO: Select Subject
                            }) {
                                Image(systemName: "person.and.background.dotted")
                            }
                            Button(action: {
                                // TODO: Upscale Text
                            }) {
                                Image(systemName: "character.magnify")
                            }
                        }
                    }
            }
        }
        .navigationTransition(.fade(.in))
    }
}

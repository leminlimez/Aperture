//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI

let BOTTOM_BAR_PADDING: CGFloat = 18

struct EditorView: View {
    @State var image: UIImage
    @State var subject: UIImage?
    
    @State var findingSubject: Bool = false
    
    var body: some View {
        ZStack {
            ZoomableView {
                Image(uiImage: image)
                    .resizable()
                    .opacity(subject == nil ? 1.0 : 0.2)
                    .shine(findingSubject)
                    .overlay(content: {
                        GeometryReader { geometry in
                            // MARK: Subject Only
                            if let subject = subject {
                                Image(uiImage: subject)
                                    .resizable()
                                    .frame(
                                        width: (subject.size.width / image.size.width) * geometry.size.width,
                                        height: (subject.size.height / image.size.height) * geometry.size.height
                                    )
                                    .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
                            }
                        }
                    })
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
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
                        // MARK: Select Subject
                        if !findingSubject {
                            findingSubject = true
                            Task {
                                subject = nil
                                subject = await getSubject(from: image)
                                if subject == nil {
                                    UIApplication.shared.alert(title: "Failed to find subject", body: "No subject could be found in the image!")
                                }
                                findingSubject = false
                            }
                        }
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
}

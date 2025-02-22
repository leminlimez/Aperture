//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import CoreML

let BOTTOM_BAR_PADDING: CGFloat = 12

enum Tool {
    case none, box
}

struct EditorView: View {
    // View Models
    var imageOCR = OCR()
    
    // Images
    @State var image: UIImage
    @State var subject: UIImage?
    @State var upscaledImage: UIImage?
    @State var sentImage: UIImage?
    
    @State private var currentTool: Tool = .none
    @State private var showResultsView: Bool = false
    
    // Bounding Box
    @State private var boxStartPos: CGPoint? = nil
    @State private var currentBox: Path? = nil
    
    // Gloss Properties
    @State private var playingGlossAnim: Bool = false
    @State private var animStartTime: Date? = nil
    @State private var imageFadeAmount: Double = 1.0
    
    var body: some View {
        VStack {
            ZoomableView {
                Image(uiImage: image)
                    .resizable()
                    .opacity(imageFadeAmount)
                    .transition(.opacity)
                    .animation(.easeOut, value: imageFadeAmount)
                    .shine(playingGlossAnim)
                    .overlay(content: {
                        ZStack {
                            // MARK: Subject View
                            if let subject = subject {
                                Image(uiImage: subject)
                                    .resizable()
                                    .transition(.opacity)
                            }
                            
                            // MARK: Detected Text View
                            if imageOCR.showObservations {
                                ForEach(imageOCR.observations, id: \.self) { observation in
                                    Box(observation: observation)
                                        .fill(Color.black.opacity(0.3))
                                        .overlay {
                                            Text(observation.topCandidates(1).first?.string ?? "????")
                                                .frame(width: observation.boundingBox.width, height: observation.boundingBox.height)
                                                .position(observation.boundingBox.toImageCoordinates(image.size, origin: .upperLeft).origin)
                                                .font(.system(size: 100))
                                                .minimumScaleFactor(0.1)
                                                .scaledToFit()
                                                .foregroundStyle(.white)
                                                .textSelection(.enabled)
                                        }
                                }
                            }
                            
                            // MARK: Bounding Box
                            if let currentBox = currentBox {
                                // Darkening for bounding box
                                Color.black
                                    .opacity(0.7)
                                    .overlay {
                                        currentBox
                                            .fill(.black)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                currentBox
                                    .strokedPath(.init(
                                        lineWidth: boxStartPos == nil ? 3 : 2,
                                        lineJoin: .round,
                                        dash: boxStartPos == nil ? [] : [5]
                                    ))
                                    .foregroundStyle(.gray.opacity(0.8))
                            }
                        }
                    })
                    .aspectRatio(contentMode: .fit)
                    .padding(.vertical, 10)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if currentTool != .box {
                                    return
                                }
                                if boxStartPos == nil {
                                    boxStartPos = drag.location
                                }
                                let end = drag.location
                                let rectangle: CGRect = .init(origin: end,
                                                              size: .init(width: boxStartPos!.x - end.x,
                                                                          height: boxStartPos!.y - end.y))
                                currentBox = .init { path in
                                    path.addRect(rectangle)
                                }
                            }
                            .onEnded { _ in
                                boxStartPos = nil
                                currentTool = .none
                            }
                    )
            }
            // MARK: Bottom Bar
            HStack {
                BottomButton(icon: "lasso", action: {
                    // TODO: Lasso Tool
                })
                BottomButton(icon: "rectangle.dashed", pressed: { return currentTool == .box }, action: {
                    // MARK: Select bounding box tool
                    boxStartPos = nil
                    currentBox = nil
                    currentTool = currentTool == .box ? .none : .box
                })
                BottomButton(icon: "person.and.background.dotted", pressed: { return subject != nil}, action: {
                    // MARK: Select Subject
                    if !playingGlossAnim {
                        if subject != nil {
                            subject = nil
                            imageOCR.showObservations = false
                            fadeImage(to: 1.0)
                            return
                        }
                        startGloss()
                        Task {
                            do {
                                let foundSubject = try await maskSubject(from: image)
                                if foundSubject == nil {
                                    throw MaskingError.noSubjects
                                }
                                finishGloss({
                                    subject = foundSubject
                                }, finalFadeAmt: 0.2)
                            } catch {
                                playingGlossAnim = false
                                fadeImage(to: 1.0)
                                UIApplication.shared.alert(title: "Failed to find subject", body: error.localizedDescription)
                            }
                        }
                    }
                })
                /*BottomButton(icon: "character.magnify", pressed: { return imageOCR.showObservations }, action: {
                    // MARK: Upscale Text
                    if !playingGlossAnim {
                        if imageOCR.showObservations {
                            imageOCR.showObservations = false
                            fadeImage(to: 1.0)
                            return
                        }
                        subject = nil
                        startGloss()
                        Task {
                            do {
                                guard let imageData = image.pngData() else { throw MaskingError.noData }
                                try await imageOCR.performOCR(imageData: imageData)
                                guard imageOCR.observations.count > 0 else { throw MaskingError.noText }
                                print(imageOCR.observations)
                                finishGloss({
                                    imageOCR.showObservations = true
                                }, finalFadeAmt: 0.5)
                            } catch {
                                playingGlossAnim = false
                                fadeImage(to: 1.0)
                                UIApplication.shared.alert(title: "Failed to find text", body: error.localizedDescription)
                            }
                        }
                    }
                })*/
            }
            .frame(maxWidth: .infinity, maxHeight: 50)
            .padding(.bottom, 2)
            .padding(.top, 18)
            .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
            .navigationDestination(isPresented: $showResultsView, destination: {
                if let resultingImage = upscaledImage, let sentImage = sentImage {
                    ResultsView(originalImage: sentImage, upscaledImage: resultingImage)
                }
            })
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        // MARK: Upscale Image
                        if !playingGlossAnim {
                            startGloss()
                            Task {
                                var toSend: UIImage = image
                                if let subject = subject { toSend = subject } // subject only
//                                if let bounding = currentBox, let cropped = image.cropImage(to: bounding.boundingRect) { toSend = cropped }
                                sentImage = toSend
                                
                                self.upscaledImage = await finalizeAndUpscale(image: toSend)
                                if self.upscaledImage == nil {
                                    playingGlossAnim = false
                                    UIApplication.shared.alert(title: "Failed to upscale image.", body: "An unknown error occurred.")
                                } else {
                                    finishGloss({
                                        self.showResultsView = true
                                    }, finalFadeAmt: 1.0)
                                }
                            }
                        }
                    }) {
                        Image(systemName: "photo.badge.checkmark")
                    }
                }
            }
        }
    }
    
    struct BottomButton: View {
        var icon: String
        var pressed: () -> Bool = { return false }
        var action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Image(systemName: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .padding(8)
            .background {
                if pressed() {
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundStyle(.thinMaterial)
                } else {
                    Color.clear
                }
            }
            .padding(.horizontal, BOTTOM_BAR_PADDING)
        }
    }
    
    func startGloss() {
        playingGlossAnim = true
        animStartTime = Date()
        fadeImage(to: 0.7)
    }
    
    func finishGloss(_ action: @escaping () -> Void, finalFadeAmt: Double = 1.0) {
        if let animStartTime = animStartTime {
            let timeLeft = GLOSS_DURATION - Date().timeIntervalSince(animStartTime).truncatingRemainder(dividingBy: GLOSS_DURATION)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeLeft) {
                playingGlossAnim = false
                action()
                fadeImage(to: finalFadeAmt)
            }
        } else {
            // No start date set, just end the animation
            playingGlossAnim = false
            action()
            fadeImage(to: finalFadeAmt)
        }
    }
    
    func fadeImage(to amt: Double) {
        imageFadeAmount = amt
    }
}

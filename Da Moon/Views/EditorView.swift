//
//  EditorView.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import SwiftUI
import CoreML

let BOTTOM_BAR_PADDING: CGFloat = 12
let SUBJECT_FADE: Double = 0.2

enum Tool {
    case None, Box, Lasso
}

struct EditorView: View {
    // View Models
    var imageOCR = OCR()
    
    // Images
    @State var image: UIImage
    @State var subject: UIImage?
    @State var upscaledImage: UIImage?
    @State var sentImage: UIImage?
    
    @State private var currentTool: Tool = .None
    @State private var showResultsView: Bool = false
    
    // Bounding Box
    @State private var boxStartPos: CGPoint? = nil
    @State private var selectionPath: Path? = nil
    
    // Lasso Tool
    @State private var drawingLasso: Bool = false
    
    // Image View Bounds
    @State private var imageSize: CGSize = CGSizeZero
    @State private var imagePos: CGPoint = CGPointZero
    
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
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onChange(of: geometry.size, initial: true) {
                                    imageSize = geometry.size
                                }
                                .onChange(of: geometry.frame(in: .local).minX, initial: true) {
                                    imagePos = CGPoint(x: geometry.frame(in: .local).minX, y: geometry.frame(in: .local).minY)
                                }
                                .onChange(of: geometry.frame(in: .local).minY, initial: true) {
                                    imagePos = CGPoint(x: geometry.frame(in: .local).minX, y: geometry.frame(in: .local).minY)
                                }
                        }
                    }
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
                            
                            // MARK: Bounding Box + Lasso
                            if let selectionPath = selectionPath {
                                // Darkening for bounding box/lasso
                                Color.black
                                    .opacity(0.7)
                                    .overlay {
                                        selectionPath
                                            .fill(.black)
                                            .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                                selectionPath
                                    .strokedPath(.init(
                                        lineWidth: (!drawingLasso && boxStartPos == nil) ? 2 : 3,
                                        lineJoin: .round,
                                        dash: (!drawingLasso && boxStartPos == nil) ? [] : [5]
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
                                if currentTool == .None {
                                    return
                                }
                                if currentTool == .Box {
                                    if boxStartPos == nil {
                                        boxStartPos = drag.location
                                    }
                                    let end = getCorrectedPoint(drag.location)
                                    let rectangle: CGRect = .init(origin: end,
                                                                  size: .init(width: boxStartPos!.x - end.x,
                                                                              height: boxStartPos!.y - end.y))
                                    selectionPath = .init { path in
                                        path.addRect(rectangle)
                                    }
                                } else if currentTool == .Lasso {
                                    if !drawingLasso {
                                        selectionPath = Path()
                                        selectionPath!.move(to: drag.startLocation)
                                        drawingLasso = true
                                    }
                                    selectionPath!.addLine(to: getCorrectedPoint(drag.location))
                                }
                            }
                            .onEnded { drag in
                                if drawingLasso && selectionPath != nil {
                                    selectionPath!.addLine(to: drag.location)
                                    selectionPath!.closeSubpath()
                                    drawingLasso = false
                                }
                                boxStartPos = nil
                                currentTool = .None
                            }
                    )
            }
            // MARK: Bottom Bar
            HStack {
                BottomButton(icon: "trash", action: {
                    // MARK: Remove Selection
                    guard boxStartPos == nil && !drawingLasso else { return } // do not clear if they are in the middle of drawing
                    selectionPath = nil
                    currentTool = .None
                })
                .foregroundStyle(.red)
                .disabled(selectionPath == nil)
                .opacity(selectionPath == nil ? 0.4 : 1.0)
                BottomButton(icon: "lasso", pressed: { return currentTool == .Lasso }, action: {
                    // MARK: Lasso Tool
                    guard boxStartPos == nil else { return } // do not change tool if currently drawing box
                    currentTool = currentTool == .Lasso ? .None : .Lasso
                })
                BottomButton(icon: "rectangle.dashed", pressed: { return currentTool == .Box }, action: {
                    // MARK: Select bounding box tool
                    guard !drawingLasso else { return } // do not change tool if currently drawing lasso
                    boxStartPos = nil
                    currentTool = currentTool == .Box ? .None : .Box
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
                                }, finalFadeAmt: SUBJECT_FADE)
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
            .onAppear {
                // set the fade back if there is already a subject
                if subject != nil {
                    fadeImage(to: SUBJECT_FADE)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: {
                        // MARK: Upscale Image
                        if !playingGlossAnim {
                            startGloss(fade: subject != nil ? SUBJECT_FADE : 0.7)
                            Task {
                                var toSend: UIImage = image
                                if let subject = subject { toSend = subject } // subject only
                                // crop the sending image to the bounding box
                                if let path = selectionPath, let cropped = toSend.cropImage(path: path, in: imageSize) { toSend = cropped }
                                // fill the background of transparent images with white or the darkened background
                                let darkenBG = UserDefaults.standard.bool(forKey: "useDarkenedBG")
                                if darkenBG, let filled = toSend.overlayDarkened(over: image) {
                                    toSend = filled
                                } else if !darkenBG, let filled = toSend.fillTransparency(with: UIColor.white.cgColor) {
                                    toSend = filled
                                }
                                sentImage = toSend
                                
//                                self.upscaledImage = await finalizeAndUpscale(image: toSend)
//                                self.upscaledImage = await finalizeAndUpscaleServer(image: toSend)
                                self.upscaledImage = await combinedUpscale(image: toSend)
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
    
    func startGloss(fade: Double = 0.7) {
        playingGlossAnim = true
        animStartTime = Date()
        fadeImage(to: fade)
    }
    
    func finishGloss(_ action: @escaping () -> Void, finalFadeAmt: Double = 1.0) {
        if let animStartTime = animStartTime {
            let animTime = GLOSS_DURATION + 0.05
            let timeLeft = animTime - Date().timeIntervalSince(animStartTime).truncatingRemainder(dividingBy: animTime)
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
    
    func getCorrectedPoint(_ point: CGPoint) -> CGPoint {
        var newPoint = point
        let maxY = imagePos.y + imageSize.height
        if newPoint.y > maxY {
            newPoint.y = maxY
        } else if newPoint.y < imagePos.y {
            newPoint.y = imagePos.y
        }
        return newPoint
    }
}

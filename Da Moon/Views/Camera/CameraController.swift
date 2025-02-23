//
//  CameraController.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

// adapted from https://stackoverflow.com/questions/58847638/swiftui-custom-camera-view

import SwiftUI
import AVFoundation

let PinchVelocityDividerFactor: CGFloat = 20.0

class CustomCameraController: UIViewController {
    var image: UIImage?
    var error: CameraError? = nil
    
    var captureSession = AVCaptureSession()
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    let screenWidth = UIScreen.main.bounds.size.width
    let screenHeight = UIScreen.main.bounds.size.height
    
    //DELEGATE
    var delegate: AVCapturePhotoCaptureDelegate?
    
    func didTapRecord() {
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: delegate!)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    func setup() {
        setupCaptureSession()
        setupDevice()
        if currentCamera != nil {
            setupInputOutput()
            setupPreviewLayer()
            startRunningCaptureSession()
        } else {
            error = .notFound
        }
    }
    
    func setupCaptureSession() {
        captureSession.sessionPreset = .photo
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera],
                                                                      mediaType: .video,
                                                                      position: .back)
        for device in deviceDiscoverySession.devices {
            if (
                device.deviceType == .builtInTripleCamera
                || (device.deviceType == .builtInDualWideCamera && (self.currentCamera == nil || self.currentCamera?.deviceType == .builtInWideAngleCamera))
                || (device.deviceType == .builtInWideAngleCamera && self.currentCamera == nil)
            ) {
                // prioritize triple camera setup (iPhone Pros)
                // then double camera setup (regular iPhones)
                // and finally single camera setup (iPads)
                self.currentCamera = device
            }
        }
    }
    
    
    func setupInputOutput() {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
        } catch {
            print(error)
        }
        
    }
    
    func setupPreviewLayer() {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.cameraPreviewLayer?.videoGravity = .resizeAspectFill
        self.cameraPreviewLayer?.connection?.videoOrientation = .portrait
        // manually set the height because it does not conform to SwiftUI's (not great)
        let offsetX: CGFloat = 20
        self.cameraPreviewLayer?.frame = CGRect(
            x: offsetX,
            y: 0,
            width: screenWidth - offsetX * 2,
            height: screenHeight - CameraViewOffset
        )
        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        
        // set up pinch gesture
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action:#selector(handlePinchGesture(_:)))
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    func startRunningCaptureSession() {
        captureSession.startRunning()
    }
    
    private func zoom(_ velocity: CGFloat) {
        do {
            guard let currentCamera = currentCamera else { return }
            try currentCamera.lockForConfiguration()
            defer { currentCamera.unlockForConfiguration() }

            var minZoomFactor: CGFloat = currentCamera.minAvailableVideoZoomFactor
            let maxZoomFactor: CGFloat = currentCamera.maxAvailableVideoZoomFactor
            
            let desiredZoomFactor = currentCamera.videoZoomFactor + atan2(velocity, PinchVelocityDividerFactor)
            
            let zoomScale = max(minZoomFactor, min(desiredZoomFactor, maxZoomFactor))
            currentCamera.videoZoomFactor = zoomScale

            currentCamera.unlockForConfiguration()
        } catch {
            print("Error locking camera configuration")
        }
    }

    @objc private func handlePinchGesture(_ recognizer: UIPinchGestureRecognizer) {
        var allTouchesOnPreviewLayer = true
        let numTouch = recognizer.numberOfTouches
        
        if self.cameraPreviewLayer != nil {
            for i in 0 ..< numTouch {
                let location = recognizer.location(ofTouch: i, in: view)
                let convertedTouch = self.cameraPreviewLayer!.convert(location, from: self.cameraPreviewLayer!.superlayer)
                if !self.cameraPreviewLayer!.contains(convertedTouch) {
                    allTouchesOnPreviewLayer = false
                    break
                }
            }
        }
        if allTouchesOnPreviewLayer {
            zoom(recognizer.velocity)
        }
    }
}

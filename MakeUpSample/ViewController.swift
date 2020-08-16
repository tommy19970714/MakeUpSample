//
//  ViewController.swift
//  MakeUpSample
//
//  Created by 冨平準喜 on 2020/07/30.
//  Copyright © 2020 冨平準喜. All rights reserved.
//

import Cocoa
import AVFoundation
import MetalPetal

class ViewController: NSViewController {

    // MARK: - Properties
    fileprivate var videoSession: AVCaptureSession!
    fileprivate var cameraDevice: AVCaptureDevice!
    fileprivate let faceDetector = FaceLandmarksDetector()
    @IBOutlet weak var imageView: NSImageView!
    fileprivate var captureCounter = 0
    fileprivate var filterType = FilterType.skinSmoothing // Choice Filter type
    fileprivate var drawLandmark = true // If you want to draw landmark in your camera, please choice true
    fileprivate var drawLip = true
    fileprivate var resizeEye = true
    
    enum FilterType {
        case skinSmoothing
        case dotScreen
        case none
    }
    
    // MARK: - LyfeCicle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.prepareCamera()
        self.startSession()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}


// MARK: - Prepare&Start&Stop camera
extension ViewController {
    
    func startSession() {
        if let videoSession = videoSession {
            if !videoSession.isRunning {
                videoSession.startRunning()
            }
        }
    }
    
    func stopSession() {
        if let videoSession = videoSession {
            if videoSession.isRunning {
                videoSession.stopRunning()
            }
        }
    }
    
    fileprivate func prepareCamera() {
        self.videoSession = AVCaptureSession()
        self.videoSession.sessionPreset = AVCaptureSession.Preset.photo
        self.cameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
        
        if cameraDevice != nil  {
            do {
                let input = try AVCaptureDeviceInput(device: cameraDevice)
                
                
                if videoSession.canAddInput(input) {
                    videoSession.addInput(input)
                }
            } catch {
                print(error.localizedDescription)
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: .main)
            videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)]
            videoOutput.alwaysDiscardsLateVideoFrames = true

            if videoSession.canAddOutput(videoOutput) {
                videoSession.addOutput(videoOutput)
            }
        }
    }
}


// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        captureCounter += 1
        if captureCounter % 10 != 0 {
            return
        }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let w = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let h = CGFloat(CVPixelBufferGetHeight(imageBuffer))
        let rect:CGRect = CGRect.init(x: 0, y: 0, width: w, height: h)
        let context = CIContext.init()
        guard let cgImage = context.createCGImage(ciImage, from: rect) else { return }
        
        faceDetector.highlightFaces(for: cgImage) { [weak self] faceObservations in
            guard let self = self else { return }
            
            // Please write here
            // You can add filter of eye or noise or mouth
            
            guard var outputImage = self.addFilter(cgImage: cgImage) else { return }
            if self.drawLandmark {
                outputImage = self.faceDetector.drawAllLandmarkds(for: outputImage, faceObservations: faceObservations)
            }
            if self.drawLip {
                outputImage = self.faceDetector.fillLip(for: outputImage, faceObservations: faceObservations)
            }
            
            if self.resizeEye {
                outputImage = self.faceDetector.resizeEye(for: outputImage, faceObservations: faceObservations)
            }
            
            DispatchQueue.main.async {
                let image = NSImage(cgImage: outputImage, size: NSSize(width: w, height: h))
                self.imageView.image = image
            }
        }
    }
    
    func addFilter(cgImage: CGImage) -> CGImage? {
        guard let device = MTLCreateSystemDefaultDevice(), let mticontext = try? MTIContext(device: device) else {
            return nil
        }
        let mtiImage = MTIImage(cgImage: cgImage).unpremultiplyingAlpha()
        var filteredImage: MTIImage? = mtiImage
        
        switch filterType {
        case .skinSmoothing:
            let filter = MTIHighPassSkinSmoothingFilter()
            filter.amount = 1
            filter.radius = 7
            filter.inputImage = mtiImage
            filteredImage = filter.outputImage
        case .dotScreen:
            let filter = MTIDotScreenFilter()
            filter.inputImage = mtiImage
            filteredImage = filter.outputImage
        case .none:
            break
        }
        
        if let filtered = filteredImage, let cgImage = try? mticontext.makeCGImage(from: filtered) {
            return cgImage
        }
        return nil
    }
}

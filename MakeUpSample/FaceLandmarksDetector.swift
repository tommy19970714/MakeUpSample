//
//  FaceLandmarksDetector.swift
//  MakeUpSample
//
//  Created by 冨平準喜 on 2020/07/30.
//  Copyright © 2020 冨平準喜. All rights reserved.
//
// reference
// https://github.com/mihailsalari/macOS-Camera/blob/master/macOS%20Camera/ViewController.swift


import Cocoa
import Vision

class FaceLandmarksDetector {

    open func highlightFaces(for source: CGImage, complete: @escaping ([VNFaceObservation]) -> Void) {
        var faceObservations = [VNFaceObservation]()
        let detectFaceRequest = VNDetectFaceLandmarksRequest { (request, error) in
            if error == nil {
                if let results = request.results as? [VNFaceObservation] {
                    faceObservations = results
                }
            } else {
                print(error!.localizedDescription)
            }
            complete(faceObservations)
        }
        let vnImage = VNImageRequestHandler(cgImage: source, options: [:])
        try? vnImage.perform([detectFaceRequest])
    }
    
    open func drawAllLandmarkds(for source: CGImage, faceObservations: [VNFaceObservation]) -> CGImage {
        var drawImage = source
        
        for faceObservation in faceObservations {
            guard let landmarks = faceObservation.landmarks else {
                continue
            }
            
            var points:[VNFaceLandmarkRegion2D] = []
            
            // Add each observation to the points array seprately, so we can
            // connect each part individually
            if let faceContour = landmarks.faceContour {
                points.append(faceContour)
            }
            if let medianLine = landmarks.medianLine {
                points.append(medianLine)
            }
            if let leftEye = landmarks.leftEye {
                points.append(leftEye)
            }
            if let rightEye = landmarks.rightEye {
                points.append(rightEye)
            }
            if let nose = landmarks.nose {
                points.append(nose)
            }
            if let noseCrest = landmarks.noseCrest {
                points.append(noseCrest)
            }
            if let outerLips = landmarks.outerLips {
                points.append(outerLips)
            }
            if let leftEyebrow = landmarks.leftEyebrow {
                points.append(leftEyebrow)
            }
            if let rightEyebrow = landmarks.rightEyebrow {
                points.append(rightEyebrow)
            }
            if let innerLips = landmarks.innerLips {
                points.append(innerLips)
            }
            if let leftPupil = landmarks.leftPupil {
                points.append(leftPupil)
            }
            if let rightPupil = landmarks.rightPupil {
                points.append(rightPupil)
            }
            
            drawImage = self.drawLandmarkds(source: source, points: points, boundingBox: faceObservation.boundingBox)
        }
        return drawImage
    }
    
    private func drawLandmarkds(source:CGImage, points:[VNFaceLandmarkRegion2D], boundingBox:CGRect) -> CGImage {
        // Reference
        // https://github.com/xiaohk/FaceData/blob/76fcda5d42c5db968850dfc28f287e6ec80f431b/FaceData/TrainingConverter.swift#L121
        
        
        // UIKit is not supported on MacOS, so we have to use a CGContext
        let colorSpace = CGColorSpaceCreateDeviceRGB()//CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let context = CGContext(data: nil,
                                width: source.width,
                                height: source.height,
                                bitsPerComponent: 8,
                                bytesPerRow: 0,
                                space: colorSpace,
                                bitmapInfo: bitmapInfo.rawValue)!
        
        context.setLineJoin(.round)
        context.setLineCap(.round)
        // Make the pixel look more smooth
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // Draw landmarks
        context.setStrokeColor(CGColor.white)
        context.setLineWidth(2.0)
        
        let rectWidth = CGFloat(source.width) * boundingBox.size.width
        let rectHeight = CGFloat(source.height) * boundingBox.size.height
        let originX = boundingBox.origin.x * CGFloat(source.width)
        let originY = boundingBox.origin.y * CGFloat(source.height)
        let rect = CGRect(x: 0, y: 0, width: CGFloat(source.width), height: CGFloat(source.height))
        
        context.draw(source, in: rect)
        context.addRect(CGRect(x: originX, y: originY, width: rectWidth, height: rectHeight))
        
        for i in 0..<points.count {
            let landmark = points[i]
            let points = landmark.normalizedPoints
            
            // The points are normalized, we have to scale them back (using the
            // bounding box)
            let scaledPoints = points.map {
                CGPoint(x: originX + $0.x * rectWidth,
                        y: originY + $0.y * rectHeight) }
            
            context.addLines(between: scaledPoints)
            
            // If the points are not from contor or medle line, we close the connections
            if i > 1{
                context.move(to: scaledPoints.last!)
                context.addLine(to: scaledPoints.first!)
            }
            context.drawPath(using: CGPathDrawingMode.stroke)
        }

        return context.makeImage()!
    }
}

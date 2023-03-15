/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit
import Vision

extension UIView {
    func snapshot(replacingTransparentWithWhite: Bool = false) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }

        if replacingTransparentWithWhite {
            // Create a new image context to modify the image data
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: image.size))
            // Draw the original image on top, replacing transparent parts with white
            image.draw(at: .zero, blendMode: .normal, alpha: 1.0)
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return newImage
        } else {
            return image
        }
    }
}

internal class SwiftUISnapshotRecorder: NodeRecorder {

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard String(describing: view).contains("SwiftUI") else {
            return nil
        }
        guard let snapshot = view.snapshot(replacingTransparentWithWhite: true) else {
            return nil
        }
        if #available(iOS 13.0, *) {
            let builder = SwiftUIWireframesBuilder(
                wireframeIDs: context.ids.nodeIDs(64, for: view),
                attributes: attributes,
                wireframeRect: view.frame,
                snapshot: snapshot
            )
            let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
            return SpecificElement(subtreeStrategy: .ignore, nodes: [node])
        } else {
            return nil
        }
    }
}

@available(iOS 13.0, *)
internal class SwiftUIWireframesBuilder: NodeWireframesBuilder {
    let wireframeIDs: [WireframeID]
    /// Attributes of the `UIView`.
    let attributes: ViewAttributes

    let wireframeRect: CGRect

    let snapshot: UIImage

    let imageRequestHandler: VNImageRequestHandler?

    let rectDetectRequest: VNDetectRectanglesRequest?
    let textDetectRequest: VNRecognizeTextRequest?

    internal init(
        wireframeIDs: [WireframeID],
        attributes: ViewAttributes,
        wireframeRect: CGRect,
        snapshot: UIImage
    ) {
        self.wireframeIDs = wireframeIDs
        self.attributes = attributes
        self.snapshot = snapshot
        self.wireframeRect = wireframeRect
        if let cgImage = snapshot.cgImage {
            self.imageRequestHandler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )
        } else {
            self.imageRequestHandler = nil
        }

        self.rectDetectRequest = VNDetectRectanglesRequest()
        rectDetectRequest?.maximumObservations = 16
        rectDetectRequest?.minimumConfidence = 0.9
        rectDetectRequest?.minimumAspectRatio = 0
        rectDetectRequest?.maximumAspectRatio = 1
        rectDetectRequest?.minimumSize = 0.1

        self.textDetectRequest = VNRecognizeTextRequest()

        try? imageRequestHandler?.perform([textDetectRequest].compactMap { $0 })
    }

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        var index = 0
        let rects = rectDetectRequest?.results.map {
            $0.map { (observation: VNRectangleObservation) -> SRWireframe in
                let boundingBox = observation.boundingBox
                let frame = CGRect(
                    x: boundingBox.origin.x * attributes.frame.width,
                    y: (1 - boundingBox.origin.y) * attributes.frame.height - boundingBox.size.height * attributes.frame.height,
                    width: boundingBox.size.width * attributes.frame.width,
                    height: boundingBox.size.height * attributes.frame.height
                )
                index += 1
                return builder.createShapeWireframe(
                    id: wireframeIDs[index],
                    frame: frame,
                    backgroundColor: snapshot.medianColorForRect(
                        rect: VNImageRectForNormalizedRect(
                            boundingBox,
                            Int(snapshot.size.width),
                            Int(snapshot.size.height)
                        )
                    )?.cgColor
                )
            }
        } ?? []

        let texts = textDetectRequest?.results.map {
            $0.compactMap { (observation: VNRecognizedTextObservation) -> SRWireframe? in
                guard let candidate = observation.topCandidates(1).first else { return nil }
                let stringRange = candidate.string.startIndex..<candidate.string.endIndex
                let boxObservation = try? candidate.boundingBox(for: stringRange)
                let boundingBox = boxObservation?.boundingBox ?? .zero
                let frame = CGRect(
                    x: boundingBox.origin.x * attributes.frame.width + attributes.frame.origin.x,
                    y: (1 - boundingBox.origin.y) * attributes.frame.height - boundingBox.size.height * attributes.frame.height + attributes.frame.origin.y,
                    width: boundingBox.size.width * attributes.frame.width,
                    height: boundingBox.size.height * attributes.frame.height
                )
                index += 1
                return builder.createTextWireframe(
                    id: wireframeIDs[index],
                    frame: frame,
                    text: candidate.string,
                    textAlignment: .init(horizontal: .center, vertical: .center),
                    textColor: UIColor.black.cgColor,
                    font: UIFont.systemFont(ofSize: 15)
                )
            }
        } ?? []

        return [
            builder.createShapeWireframe(id: wireframeIDs[0], frame: wireframeRect, attributes: attributes)
        ] + rects + texts
    }
}

extension UIImage {
    func medianColorForRect(rect: CGRect) -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        let width = Int(rect.width)
        let height = Int(rect.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bytesCount = bytesPerRow * height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: bytesCount)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        context?.draw(cgImage, in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: self.size.width, height: self.size.height))
        var rgbValues = [(red: UInt8, green: UInt8, blue: UInt8)]()
        for i in 0..<pixels.count/bytesPerPixel {
            let offset = i * bytesPerPixel
            let red = pixels[offset]
            let green = pixels[offset + 1]
            let blue = pixels[offset + 2]
            rgbValues.append((red, green, blue))
        }
        rgbValues.sort { (lhs, rhs) -> Bool in
            let luma1 = Double(lhs.red) * 0.299 + Double(lhs.green) * 0.587 + Double(lhs.blue) * 0.114
            let luma2 = Double(rhs.red) * 0.299 + Double(rhs.green) * 0.587 + Double(rhs.blue) * 0.114
            return luma1 < luma2
        }
        let medianIndex = rgbValues.count / 2
        let medianColor = UIColor(red: CGFloat(rgbValues[medianIndex].red)/255.0, green: CGFloat(rgbValues[medianIndex].green)/255.0, blue: CGFloat(rgbValues[medianIndex].blue)/255.0, alpha: 1.0)
        return medianColor
    }
}

extension UIImage {
    func averageColorForRect(rect: CGRect) -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        let width = Int(rect.width)
        let height = Int(rect.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bytesCount = bytesPerRow * height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: bytesCount)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        context?.draw(cgImage, in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: self.size.width, height: self.size.height))
        var red = 0
        var green = 0
        var blue = 0
        for i in 0..<pixels.count/bytesPerPixel {
            let offset = i * bytesPerPixel
            red += Int(pixels[offset])
            green += Int(pixels[offset + 1])
            blue += Int(pixels[offset + 2])
        }
        let pixelCount = pixels.count/bytesPerPixel
        let averageRed = UInt8(red/pixelCount)
        let averageGreen = UInt8(green/pixelCount)
        let averageBlue = UInt8(blue/pixelCount)
        let averageColor = UIColor(red: CGFloat(averageRed)/255.0, green: CGFloat(averageGreen)/255.0, blue: CGFloat(averageBlue)/255.0, alpha: 1.0)
        return averageColor
    }
}

extension UIImage {
    func randomAverageColorForRect(rect: CGRect, pixelCount: Int) -> UIColor? {
        guard let cgImage = self.cgImage else { return nil }
        let width = Int(rect.width)
        let height = Int(rect.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bytesCount = bytesPerRow * height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: bytesCount)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        context?.draw(cgImage, in: CGRect(x: -rect.origin.x, y: -rect.origin.y, width: self.size.width, height: self.size.height))
        var red = 0
        var green = 0
        var blue = 0
        for _ in 0..<pixelCount {
            let x = Int.random(in: 0..<Int(rect.width))
            let y = Int.random(in: 0..<Int(rect.height))
            let index = (y * bytesPerRow) + (x * bytesPerPixel)
            red += Int(pixels[index])
            green += Int(pixels[index + 1])
            blue += Int(pixels[index + 2])
        }
        let averageRed = UInt8(red/pixelCount)
        let averageGreen = UInt8(green/pixelCount)
        let averageBlue = UInt8(blue/pixelCount)
        let averageColor = UIColor(red: CGFloat(averageRed)/255.0, green: CGFloat(averageGreen)/255.0, blue: CGFloat(averageBlue)/255.0, alpha: 1.0)
        return averageColor
    }
}

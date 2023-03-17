/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit
import Vision

extension UIView {
    func snapshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
        return image
    }
}

extension UIImage {
    func replaceTransparentWith(_ color: UIColor) -> UIImage {
        // Create a new image context to modify the image data
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        // Draw the original image on top, replacing transparent parts with white
        draw(at: .zero, blendMode: .normal, alpha: 1.0)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? UIImage()
    }
}

internal class SwiftUISnapshotRecorder: NodeRecorder {

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard String(describing: view).contains("SwiftUI") else {
            return nil
        }
        guard let snapshot = view.snapshot() else {
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
    let fontColor: UIColor

    let imageRequestHandler: VNImageRequestHandler?
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
        self.fontColor = snapshot.medianColor() ?? UIColor.black
        if let cgImage = snapshot.replaceTransparentWith(fontColor.inverted()).cgImage {
            self.imageRequestHandler = VNImageRequestHandler(
                cgImage: cgImage,
                options: [:]
            )
        } else {
            self.imageRequestHandler = nil
        }

        self.textDetectRequest = VNRecognizeTextRequest()

        try? imageRequestHandler?.perform([textDetectRequest].compactMap { $0 })
    }

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        var index = 0

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
                    textColor: fontColor.cgColor,
                    font: UIFont.systemFont(ofSize: frame.height),
                    fontScalingEnabled: true
                )
            }
        } ?? []

        return [
            builder.createShapeWireframe(id: wireframeIDs[0], frame: wireframeRect, attributes: attributes)
        ] + texts
    }
}


import UIKit

extension UIImage {
    func getPixels() -> [UIColor] {
        guard let cgImage = self.cgImage else { return [] }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: height * width * bytesPerPixel)
        let bitmapInfo: UInt32 = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            rawData.deallocate()
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [UIColor] = []
        for y in 0 ..< height {
            for x in 0 ..< width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let red = CGFloat(rawData[offset]) / 255.0
                let green = CGFloat(rawData[offset + 1]) / 255.0
                let blue = CGFloat(rawData[offset + 2]) / 255.0
                let alpha = CGFloat(rawData[offset + 3]) / 255.0
                let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
                if alpha > 0 {
                    pixels.append(color)
                }
            }
        }

        rawData.deallocate()
        return pixels
    }

    func medianColor() -> UIColor? {
        return medianColor(from: getPixels())
    }

    func medianColor(from pixels: [UIColor]) -> UIColor? {
        if pixels.isEmpty {
            return nil
        }

        var reds: [CGFloat] = []
        var greens: [CGFloat] = []
        var blues: [CGFloat] = []

        for color in pixels {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            reds.append(r)
            greens.append(g)
            blues.append(b)
        }

        reds.sort()
        greens.sort()
        blues.sort()

        let mid = pixels.count / 2
        let medianRed = pixels.count % 2 == 0 ? (reds[mid - 1] + reds[mid]) / 2.0 : reds[mid]
        let medianGreen = pixels.count % 2 == 0 ? (greens[mid - 1] + greens[mid]) / 2.0 : greens[mid]
        let medianBlue = pixels.count % 2 == 0 ? (blues[mid - 1] + blues[mid]) / 2.0 : blues[mid]

        return UIColor(red: medianRed, green: medianGreen, blue: medianBlue, alpha: 1)
    }
}

import UIKit

func optimalFont(for text: String, in frame: CGRect, withFont font: UIFont, minFontSize: CGFloat = 1, maxFontSize: CGFloat = 200) -> UIFont {
    let sizeToFit = frame.size
    let constraintSize = CGSize(width: sizeToFit.width, height: CGFloat.greatestFiniteMagnitude)
    let context = NSStringDrawingContext()

    var lowerFontSize = minFontSize
    var upperFontSize = maxFontSize
    var currentFontSize: CGFloat

    while (upperFontSize - lowerFontSize) > 0.1 {
        currentFontSize = (lowerFontSize + upperFontSize) / 2.0
        let newFont = font.withSize(currentFontSize)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let attributedText = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: newFont])

        let boundingRect = attributedText.boundingRect(with: constraintSize, options: options, context: context)

        if boundingRect.height <= sizeToFit.height {
            lowerFontSize = currentFontSize
        } else {
            upperFontSize = currentFontSize
        }
    }

    return font.withSize(lowerFontSize)
}

extension UIColor {
    func inverted() -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let invertedRed = 1.0 - red
        let invertedGreen = 1.0 - green
        let invertedBlue = 1.0 - blue

        return UIColor(red: invertedRed, green: invertedGreen, blue: invertedBlue, alpha: alpha)
    }
}

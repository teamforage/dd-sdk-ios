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
            context.setFillColor(UIColor.gray.cgColor)
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
                    textColor: UIColor.black.cgColor,
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

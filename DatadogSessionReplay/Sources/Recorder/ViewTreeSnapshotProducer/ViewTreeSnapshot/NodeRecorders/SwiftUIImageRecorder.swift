/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import UIKit

extension CALayer {
    func snapshot() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(bounds.size, isOpaque, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
}


internal class SwiftUIImageRecorder: NodeRecorder {

    let imageProvider = ImageDataProvider()

    func semantics(of view: UIView, with attributes: ViewAttributes, in context: ViewTreeRecordingContext) -> NodeSemantics? {
        guard view.layer.description.contains("SwiftUI.ImageLayer") else {
            return nil
        }
        let snapshot = view.layer.snapshot()
        let builder = SwiftUIImageWireframesBuilder(
            wireframeIDs: context.ids.nodeIDs(1, for: view),
            attributes: attributes,
            wireframeRect: view.frame,
            snapshot: snapshot,
            imageProvider: imageProvider
        )
        let node = Node(viewAttributes: attributes, wireframesBuilder: builder)
        return SpecificElement(subtreeStrategy: .ignore, nodes: [node])
    }
}

internal struct SwiftUIImageWireframesBuilder: NodeWireframesBuilder {
    let wireframeIDs: [WireframeID]
    /// Attributes of the `UIView`.
    let attributes: ViewAttributes

    let wireframeRect: CGRect

    let snapshot: UIImage

    let imageProvider: ImageDataProvider

    func buildWireframes(with builder: WireframesBuilder) -> [SRWireframe] {
        return [
            builder.createImageWireframe(
                base64: imageProvider.contentBase64String(of: snapshot, customID: "\(wireframeIDs[0])"),
                id: wireframeIDs[0],
                frame: wireframeRect
            )
        ]
    }
}

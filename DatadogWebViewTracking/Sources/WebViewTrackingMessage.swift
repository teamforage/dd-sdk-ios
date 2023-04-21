/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation

internal typealias JSON = [String: Any]

/// Intermediate type to parse WebView messages and send them to the message bus
internal enum WebViewTrackingMessage {
    /// A log message with a JSON payload
    case log(JSON)

    /// A RUM event with a JSON payload
    case rumEvent(JSON)
}

/// Errors that can be thrown when parsing a WebView message
internal enum WebViewTrackingMessageError: Error, Equatable {
    case dataSerialization(message: String)
    case JSONDeserialization(rawJSONDescription: String)
    case invalidMessage(description: String)
    case missingKey(key: String)
}

extension WebViewTrackingMessage {
    internal enum Keys {
        static let eventType = "eventType"
        static let event = "event"
    }

    private enum EventTypes {
        static let log = "log"
    }

    /// Parses a bag of data to a `WebViewTrackingMessage`
    /// - Parameter body: Unstructured bag of data
    internal init(body: Any) throws {
        guard let message = body as? String else {
            throw WebViewTrackingMessageError.invalidMessage(description: String(describing: body))
        }

        let eventJSON = try WebViewTrackingMessage.parse(message)

        guard let type = eventJSON[Keys.eventType] as? String else {
            throw WebViewTrackingMessageError.missingKey(key: Keys.eventType)
        }

        guard let event = eventJSON[Keys.event] as? JSON else {
            throw WebViewTrackingMessageError.missingKey(key: Keys.event)
        }

        switch type {
        case EventTypes.log:
            self = .log(event)
        default:
            self = .rumEvent(event)
        }
    }

    private static func parse(_ message: String) throws -> JSON {
        guard let data = message.data(using: .utf8) else {
            throw WebViewTrackingMessageError.dataSerialization(message: message)
        }
        let rawJSON = try JSONSerialization.jsonObject(with: data, options: [])
        guard let json = rawJSON as? JSON else {
            throw WebViewTrackingMessageError.JSONDeserialization(rawJSONDescription: String(describing: rawJSON))
        }
        return json
    }
}

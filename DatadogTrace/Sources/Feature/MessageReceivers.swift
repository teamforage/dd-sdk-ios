/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternalFork

internal struct CoreContext {
    /// The RUM attributes that should be added as Span tags.
    ///
    /// These attributes are synchronized using a read-write lock.
    var rum: [String: String?]?

    /// Provides the history of app foreground / background states.
    var applicationStateHistory: AppStateHistory?
}

internal final class ContextMessageReceiver: FeatureMessageReceiver {
    let bundleWithRumEnabled: Bool

    /// The up-to-date core context.
    ///
    /// The context is synchronized using a read-write lock.
    @ReadWriteLock
    var context: CoreContext = .init()

    init(bundleWithRumEnabled: Bool) {
        self.bundleWithRumEnabled = bundleWithRumEnabled
    }

    /// Process messages receives from the bus.
    ///
    /// - Parameters:
    ///   - message: The Feature message
    ///   - core: The core from which the message is transmitted.
    func receive(message: FeatureMessage, from core: DatadogCoreProtocol) -> Bool {
        switch message {
        case .context(let context):
            return update(context: context)
        default:
            return false
        }
    }

    /// Updates context of the `DatadogTracer` if available.
    ///
    /// - Parameter context: The updated core context.
    private func update(context: DatadogContext) -> Bool {
        _context.mutate {
            $0.applicationStateHistory = context.applicationStateHistory

            if bundleWithRumEnabled, let attributes: [String: String?] = context.featuresAttributes["rum"]?.ids {
                let tags = attributes.compactMapValues { $0 }
                let mappedTags = Dictionary(uniqueKeysWithValues: tags.map { key, value in (mapRUMContextAttributeKeyToSpanTagName(key), value) })
                $0.rum = mappedTags
            }
        }

        return true
    }
}

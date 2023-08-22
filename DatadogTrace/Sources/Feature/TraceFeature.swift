/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogInternalFork

internal final class TraceFeature: DatadogRemoteFeature {
    static let name = "tracing"

    let requestBuilder: FeatureRequestBuilder
    let messageReceiver: FeatureMessageReceiver
    let tracer: DatadogTracer
    let telemetry: TelemetryCore

    init(
        in core: DatadogCoreProtocol,
        configuration: Trace.Configuration
    ) {
        let contextReceiver = ContextMessageReceiver(
            bundleWithRumEnabled: configuration.bundleWithRumEnabled
        )
        self.requestBuilder = TracingRequestBuilder(customIntakeURL: configuration.customEndpoint)
        self.messageReceiver = contextReceiver
        self.tracer = DatadogTracer(
            core: core,
            sampler: Sampler(samplingRate: configuration.debugSDK ? 100 : configuration.sampleRate),
            tags: configuration.tags ?? [:],
            service: configuration.service,
            networkInfoEnabled: configuration.networkInfoEnabled,
            spanEventMapper: configuration.eventMapper,
            tracingUUIDGenerator: configuration.traceIDGenerator,
            dateProvider: configuration.dateProvider,
            contextReceiver: contextReceiver,
            loggingIntegration: TracingWithLoggingIntegration(
                core: core,
                service: configuration.service,
                networkInfoEnabled: configuration.networkInfoEnabled
            )
        )
        self.telemetry = TelemetryCore(core: core)

        // Send configuration telemetry:
        telemetry.configuration(useTracing: true)
    }
}

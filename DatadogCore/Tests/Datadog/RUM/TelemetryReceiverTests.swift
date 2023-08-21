/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
import TestUtilities
import DatadogInternalFork

@testable import DatadogRUM

class TelemetryReceiverTests: XCTestCase {
    // MARK: - Thread safety

    func testSendTelemetryAndReset_onAnyThread() {
        let core = DatadogCoreProxy(
            context: .mockWith(
                version: .mockRandom(),
                source: .mockAnySource(),
                sdkVersion: .mockRandom()
            )
        )
        defer { core.flushAndTearDown() }

        RUM.enable(with: .mockAny(), in: core)

        let telemetry = TelemetryCore(core: core)

        // swiftlint:disable opening_brace
        callConcurrently(
            closures: [
                { telemetry.debug(id: .mockRandom(), message: "telemetry debug") },
                { telemetry.error(id: .mockRandom(), message: "telemetry error", kind: nil, stack: nil) },
                { telemetry.configuration(batchSize: .mockRandom()) },
                {
                    core.set(feature: "rum", attributes: {[
                        RUMContextAttributes.ids: [
                            RUMContextAttributes.IDs.applicationID: String.mockRandom(),
                            RUMContextAttributes.IDs.sessionID: String.mockRandom(),
                            RUMContextAttributes.IDs.viewID: String.mockRandom(),
                            RUMContextAttributes.IDs.userActionID: String.mockRandom()
                        ]
                    ]})
                }
            ],
            iterations: 50
        )
        // swiftlint:enable opening_brace
    }
}

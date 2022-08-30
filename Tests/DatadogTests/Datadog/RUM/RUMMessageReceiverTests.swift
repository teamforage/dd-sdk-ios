/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest

@testable import Datadog

class RUMMessageReceiverTests: XCTestCase {
    func testReceiveIncompleteLogMessage() throws {
        let expectation = expectation(description: "Don't send error fallback")

        // Given
        let core = PassthroughCoreMock(
            messageReceiver: RUMMessageReceiver()
        )

        Global.rum = RUMMonitor.init(core: core, dependencies: .mockAny(), dateProvider: SystemDateProvider())
        defer { Global.rum = DDNoopRUMMonitor() }

        // When
        core.send(
            message: .error(
                message: "message-test",
                attributes: [:]
            ),
            else: { expectation.fulfill() }
        )

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)
        XCTAssertTrue(core.events.isEmpty)
    }

    func testReceivePartialLogMessage() throws {
        // Given
        let core = PassthroughCoreMock(
            expectation: expectation(description: "Send Error"),
            messageReceiver: RUMMessageReceiver()
        )

        Global.rum = RUMMonitor.init(core: core, dependencies: .mockAny(), dateProvider: SystemDateProvider())
        defer { Global.rum = DDNoopRUMMonitor() }

        // When
        core.send(
            message: .error(
                message: "message-test",
                attributes: [
                    "source": "custom"
                ]
            )
        )

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        let event: RUMErrorEvent = try XCTUnwrap(core.events().last, "It should send log")
        XCTAssertEqual(event.error.message, "message-test")
        XCTAssertEqual(event.error.source, .custom)
    }

    func testReceiveCompleteLogMessage() throws {
        // Given
        let core = PassthroughCoreMock(
            expectation: expectation(description: "Send Error"),
            messageReceiver: RUMMessageReceiver()
        )

        Global.rum = RUMMonitor.init(core: core, dependencies: .mockAny(), dateProvider: SystemDateProvider())
        defer { Global.rum = DDNoopRUMMonitor() }

        // When
        core.send(
            message: .error(
                message: "message-test",
                attributes: [
                    "type": "type-test",
                    "stack": "stack-test",
                    "source": "logger"
                ]
            )
        )

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        let event: RUMErrorEvent = try XCTUnwrap(core.events().last, "It should send log")
        XCTAssertEqual(event.error.message, "message-test")
        XCTAssertEqual(event.error.type, "type-test")
        XCTAssertEqual(event.error.stack, "stack-test")
        XCTAssertEqual(event.error.source, .logger)
    }
}
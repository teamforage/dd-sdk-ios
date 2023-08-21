/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import XCTest
import TestUtilities

@testable import DatadogInternalFork
@testable import DatadogLogsFork
@testable import DatadogTrace

class TracingURLSessionHandlerTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    var core: PassthroughCoreMock!
    var tracer: DatadogTracer!
    var handler: TracingURLSessionHandler!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUp() {
        super.setUp()
        let receiver = ContextMessageReceiver(bundleWithRumEnabled: true)
        core = PassthroughCoreMock(messageReceiver: CombinedFeatureMessageReceiver([
            LogMessageReceiver.mockAny(),
            receiver
        ]))

        tracer = .mockWith(
            core: core,
            tracingUUIDGenerator: RelativeTracingUUIDGenerator(startingFrom: 1, advancingByCount: 0),
            loggingIntegration: TracingWithLoggingIntegration(core: core, service: .mockAny(), networkInfoEnabled: .mockAny())
        )

        handler = TracingURLSessionHandler(
            tracer: tracer,
            contextReceiver: receiver,
            tracingSampler: .mockKeepAll(),
            firstPartyHosts: .init([
                "www.example.com": [.datadog]
            ])
        )
    }

    override func tearDown() {
        core = nil
        super.tearDown()
    }

    func testGivenFirstPartyInterceptionWithNoError_itDoesNotSendLog() throws {
        core.expectation = expectation(description: "Send span")

        // Given
        let request: URLRequest = .mockWith(httpMethod: "POST")
        let interception = URLSessionTaskInterception(request: request, isFirstParty: true)
        interception.register(metrics: .mockAny())
        interception.register(response: .mockResponseWith(statusCode: 200), error: nil)

        // When
        handler.interceptionDidComplete(interception: interception)

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        let envelope: SpanEventsEnvelope? = core.events().last
        XCTAssertNotNil(envelope?.spans.first)

        let log: LogEvent? = core.events().last
        XCTAssertNil(log)
    }

    func testGivenFirstPartyInterceptionWithNetworkError_whenInterceptionCompletes_itEncodesRequestInfoInSpanAndSendsLog() throws {
        core.expectation = expectation(description: "Send span and log")
        core.expectation?.expectedFulfillmentCount = 2

        // Given
        let request: URLRequest = .mockWith(
            url: "http://www.example.com",
            queryParams: [
                URLQueryItem(name: "foo", value: "42"),
                URLQueryItem(name: "lang", value: "en")
            ],
            httpMethod: "GET"
        )
        let error = NSError(domain: "domain", code: 123, userInfo: [NSLocalizedDescriptionKey: "network error"])
        let interception = URLSessionTaskInterception(request: request, isFirstParty: true)
        interception.register(response: nil, error: error)
        interception.register(
            metrics: .mockWith(
                fetch: .init(
                    start: .mockDecember15th2019At10AMUTC(),
                    end: .mockDecember15th2019At10AMUTC(addingTimeInterval: 30)
                )
            )
        )

        // When
        handler.interceptionDidComplete(interception: interception)

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        let envelope: SpanEventsEnvelope? = core.events().last
        let span = try XCTUnwrap(envelope?.spans.first)
        XCTAssertEqual(span.operationName, "urlsession.request")
        XCTAssertEqual(span.resource, "http://www.example.com")
        XCTAssertEqual(span.duration, 30)
        XCTAssertTrue(span.isError)
        XCTAssertEqual(span.tags[OTTags.httpUrl], request.url!.absoluteString)
        XCTAssertEqual(span.tags[OTTags.httpMethod], "GET")
        XCTAssertEqual(span.tags[SpanTags.errorType], "domain - 123")
        XCTAssertEqual(
            span.tags[SpanTags.errorStack],
            "Error Domain=domain Code=123 \"network error\" UserInfo={NSLocalizedDescription=network error}"
        )
        XCTAssertEqual(span.tags[SpanTags.errorMessage], "network error")
        XCTAssertEqual(span.tags.count, 7)

        let log: LogEvent = try XCTUnwrap(core.events().last, "It should send error log")
        XCTAssertEqual(log.status, .error)
        XCTAssertEqual(log.message, "network error")
        XCTAssertEqual(
            log.attributes.internalAttributes?[TracingWithLoggingIntegration.TracingAttributes.traceID] as? AnyCodable,
            AnyCodable(String(span.traceID))
        )
        XCTAssertEqual(
            log.attributes.internalAttributes?[TracingWithLoggingIntegration.TracingAttributes.traceID] as? AnyCodable,
            AnyCodable(String(span.traceID))
        )
        XCTAssertEqual(
            log.attributes.internalAttributes?[TracingWithLoggingIntegration.TracingAttributes.spanID] as? AnyCodable,
            AnyCodable(String(span.spanID))
        )
        XCTAssertEqual(log.error?.kind, "domain - 123")
        XCTAssertEqual(log.attributes.internalAttributes?.count, 2)
        DDAssertJSONEqual(
            AnyEncodable(log.attributes.userAttributes[OTLogFields.event]),
            "error"
        )
        XCTAssertEqual(
            log.error?.stack,
            "Error Domain=domain Code=123 \"network error\" UserInfo={NSLocalizedDescription=network error}"
        )
        XCTAssertEqual(log.attributes.userAttributes.count, 1)
    }

    func testGivenFirstPartyInterceptionWithClientError_whenInterceptionCompletes_itEncodesRequestInfoInSpanAndSendsLog() throws {
        core.expectation = expectation(description: "Send span and log")
        core.expectation?.expectedFulfillmentCount = 2

        // Given
        let request: URLRequest = .mockWith(httpMethod: "GET")
        let interception = URLSessionTaskInterception(request: request, isFirstParty: true)
        interception.register(response: .mockResponseWith(statusCode: 404), error: nil)
        interception.register(
            metrics: .mockWith(
                fetch: .init(
                    start: .mockDecember15th2019At10AMUTC(),
                    end: .mockDecember15th2019At10AMUTC(addingTimeInterval: 2)
                )
            )
        )

        // When
        handler.interceptionDidComplete(interception: interception)

        // Then
        waitForExpectations(timeout: 0.5, handler: nil)

        let envelope: SpanEventsEnvelope? = core.events().last
        let span = try XCTUnwrap(envelope?.spans.first)
        XCTAssertEqual(span.operationName, "urlsession.request")
        XCTAssertEqual(span.resource, "404")
        XCTAssertEqual(span.duration, 2)
        XCTAssertTrue(span.isError)
        XCTAssertEqual(span.tags[OTTags.httpUrl], request.url!.absoluteString)
        XCTAssertEqual(span.tags[OTTags.httpMethod], "GET")
        XCTAssertEqual(span.tags[OTTags.httpStatusCode], "404")
        XCTAssertEqual(span.tags[SpanTags.errorType], "HTTPURLResponse - 404")
        XCTAssertEqual(span.tags[SpanTags.errorMessage], "404 not found")
        XCTAssertEqual(
            span.tags[SpanTags.errorStack],
            "Error Domain=HTTPURLResponse Code=404 \"404 not found\" UserInfo={NSLocalizedDescription=404 not found}"
        )
        XCTAssertEqual(span.tags.count, 8)

        let log: LogEvent = try XCTUnwrap(core.events().last, "It should send error log")
        XCTAssertEqual(log.status, .error)
        XCTAssertEqual(log.message, "404 not found")
        DDAssertJSONEqual(
            AnyEncodable(log.attributes.internalAttributes?[TracingWithLoggingIntegration.TracingAttributes.traceID]),
            String(span.traceID)
        )
        DDAssertJSONEqual(
            AnyEncodable(log.attributes.internalAttributes?[TracingWithLoggingIntegration.TracingAttributes.spanID]),
            String(span.spanID)
        )
        XCTAssertEqual(log.error?.kind, "HTTPURLResponse - 404")
        XCTAssertEqual(log.attributes.internalAttributes?.count, 2)
        DDAssertJSONEqual(
            AnyEncodable(log.attributes.userAttributes[OTLogFields.event]),
            "error"
        )
        XCTAssertEqual(
            log.error?.stack,
            "Error Domain=HTTPURLResponse Code=404 \"404 not found\" UserInfo={NSLocalizedDescription=404 not found}"
        )
        XCTAssertEqual(log.attributes.userAttributes.count, 1)
    }
}

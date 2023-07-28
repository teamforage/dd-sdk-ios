/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import XCTest
import TestUtilities
@testable import DatadogInternal

final class URLSessionTaskSwizzlerTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    private var core: SingleFeatureCoreMock<NetworkInstrumentationFeature>!
    private var handler: URLSessionHandlerMock!
    // swiftlint:enable implicitly_unwrapped_optional

    override func setUpWithError() throws {
        try super.setUpWithError()

        core = SingleFeatureCoreMock()
        handler = URLSessionHandlerMock()

        try core.register(urlSessionHandler: handler)
    }

    override func tearDownWithError() throws {
        core = nil
        handler = nil
        super.tearDown()
    }

    // MARK: - Bindings

    func testBindings() throws {
        func assertSwizzlingEnable(bindingsCount: UInt) {
            XCTAssertNotNil(URLSessionTaskSwizzler.resume)
            XCTAssertEqual(URLSessionTaskSwizzler.bindingsCount, bindingsCount)
        }

        func assertSwizzlingDisable() {
            XCTAssertNil(URLSessionTaskSwizzler.resume)
            XCTAssertEqual(URLSessionTaskSwizzler.bindingsCount, 0)
        }

        // binding from core
        assertSwizzlingEnable(bindingsCount: 1)

        try URLSessionTaskSwizzler.bind(intercept: self.intercept)
        assertSwizzlingEnable(bindingsCount: 2)

        URLSessionTaskSwizzler.unbind()
        assertSwizzlingEnable(bindingsCount: 1)

        URLSessionTaskSwizzler.unbind()
        assertSwizzlingDisable()
    }

    @MainActor
    @available(iOS 15.0, tvOS 15.0, *)
    func testGivenURLSessionWithDatadogDelegate_whenUsingDataFromURL_itNotifiesInterceptor() async throws {
        let notifyInterceptionStart = expectation(description: "Notify interception did start")
        let notifyInterceptionComplete = expectation(description: "Notify intercepion did complete")
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))

        handler.onInterceptionStart = { _ in
            notifyInterceptionStart.fulfill()
        }
        handler.onInterceptionComplete = { _ in
            notifyInterceptionComplete.fulfill()
        }

        // Given
        let delegate = DatadogURLSessionDelegate(in: core)
        let session = server.getInterceptedURLSession(delegate: delegate)

        // When
        let (data, _) = try await session.data(from: URL.mockAny())
        XCTAssertEqual(data.count, 10)

        // Then
        await fulfillment(
            of: [
                notifyInterceptionStart,
                notifyInterceptionComplete
            ],
            timeout: 1,
            enforceOrder: true
        )
        _ = server.waitAndReturnRequests(count: 1)
    }

//    @available(iOS 15.0, tvOS 15.0, *)
//    @MainActor
//    func testGivenURLSessionWithDatadogDelegate_whenUsingDataFromURLWithDelegate_itDetectFirstPartyHost() async throws {
//        let notifyInterceptionStart = expectation(description: "Notify interception did start")
//        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))
//
//        // Given
//        let delegate = DatadogURLSessionDelegate()
//        let session = server.getInterceptedURLSession(delegate: delegate)
//
//        handler.onInterceptionStart = {
//            // Then
//            XCTAssertTrue($0.isFirstPartyRequest)
//            notifyInterceptionStart.fulfill()
//        }
//
//        // When
//        let taskDelegate = DatadogURLSessionTaskDelegate(additionalFirstPartyHostsWithHeaderTypes: ["test.com": [.datadog]])
//        let (data, _) = try await session.data(from: URL.mockWith(url: "https://test.com"), delegate: taskDelegate)
//        XCTAssertEqual(data.count, 10)
//
//        // Then
//        await fulfillment(of: [notifyInterceptionStart], timeout: 1)
//        _ = server.waitAndReturnRequests(count: 1)
//    }

    @MainActor
    @available(iOS 15.0, tvOS 15.0, *)
    func testGivenURLSessionWithDatadogDelegate_whenUsingDataForURLRequest_itNotifiesInterceptor() async throws {
        let notifyRequestMutation = expectation(description: "Notify request mutation")
        let notifyInterceptionStart = expectation(description: "Notify interception did start")
        let notifyInterceptionComplete = expectation(description: "Notify intercepion did complete")
        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))

        handler.onRequestMutation = { _, _ in
            notifyRequestMutation.fulfill()
        }
        handler.onInterceptionStart = { _ in
            notifyInterceptionStart.fulfill()
        }
        handler.onInterceptionComplete = { _ in
            notifyInterceptionComplete.fulfill()
        }

        // Given
        let url: URL = .mockAny()
        handler.firstPartyHosts = .init(
            hostsWithTracingHeaderTypes: [url.host!: [.datadog]]
        )
        let delegate = DatadogURLSessionDelegate(in: core)
        let session = server.getInterceptedURLSession(delegate: delegate)

        // When
        let (data, _) = try await session.data(for: URLRequest(url: url))
        XCTAssertEqual(data.count, 10)

        // Then
        await fulfillment(
            of: [
                notifyRequestMutation,
                notifyInterceptionStart,
                notifyInterceptionComplete
            ],
            timeout: 1,
            enforceOrder: false
        )
        _ = server.waitAndReturnRequests(count: 1)
    }

//    @available(iOS 15.0, tvOS 15.0, *)
//    @MainActor
//    func testGivenURLSessionWithDatadogDelegate_whenUsingDataForURLRequestWithDelegate_itDetectFirstPartyHost() async throws {
//        let notifyInterceptionStart = expectation(description: "Notify interception did start")
//        let server = ServerMock(delivery: .success(response: .mockResponseWith(statusCode: 200), data: .mock(ofSize: 10)))
//
//        // Given
//        let delegate = DatadogURLSessionDelegate()
//        let session = server.getInterceptedURLSession(delegate: delegate)
//        let request: URLRequest = .mockWith(url: "https://test.com")
//
//        handler.onInterceptionStart = {
//            // Then
//            XCTAssertTrue($0.isFirstPartyRequest)
//            notifyInterceptionStart.fulfill()
//        }
//
//        // When
//        let taskDelegate = DatadogURLSessionTaskDelegate(additionalFirstPartyHostsWithHeaderTypes: ["test.com": [.datadog]])
//        let (data, _) = try await session.data(for: request, delegate: taskDelegate)
//        XCTAssertEqual(data.count, 10)
//
//        // Then
//        await fulfillment(of: [notifyInterceptionStart], timeout: 1)
//        _ = server.waitAndReturnRequests(count: 1)
//    }

    func testConcurrentBinding() throws {
        // swiftlint:disable opening_brace trailing_closure
        callConcurrently(
            closures: [
                {
                    try? URLSessionTaskSwizzler.bind(intercept: self.intercept)
                },
                {
                    URLSessionTaskSwizzler.unbind()
                },
                {
                    try? URLSessionTaskSwizzler.bind(intercept: self.intercept)
                },
                {
                    URLSessionTaskSwizzler.unbind()
                }
            ],
            iterations: 50
        )
        // swiftlint:enable opening_brace trailing_closure
    }

    func intercept(task: URLSessionTask) {
    }
}

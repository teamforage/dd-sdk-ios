/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation
import DatadogInternalFork

extension TraceID {
    public static func mockAny() -> TraceID {
        return TraceID(rawValue: .mockAny())
    }

    public static func mock(_ rawValue: UInt64) -> TraceID {
        return TraceID(rawValue: rawValue)
    }
}

public class RelativeTracingUUIDGenerator: TraceIDGenerator {
    private(set) var uuid: TraceID
    internal let count: UInt64
    private let queue = DispatchQueue(label: "queue-RelativeTracingUUIDGenerator-\(UUID().uuidString)")

    public init(startingFrom uuid: TraceID, advancingByCount count: UInt64 = 1) {
        self.uuid = uuid
        self.count = count
    }

    public func generate() -> TraceID {
        return queue.sync {
            defer { uuid = uuid + count }
            return uuid
        }
    }
}

private func + (lhs: TraceID, rhs: UInt64) -> TraceID {
    return TraceID(rawValue: (UInt64(String(lhs)) ?? 0) + rhs)
}

extension URLSession {
    public static func mockWith(_ delegate: URLSessionDelegate) -> URLSession {
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }
}

public final class URLSessionHandlerMock: DatadogURLSessionHandler {
    public var firstPartyHosts: FirstPartyHosts

    public var modifiedRequest: URLRequest?
    public var shouldInterceptRequest: ((URLRequest) -> Bool)?

    public var onRequestMutation: ((URLRequest, Set<TracingHeaderType>) -> Void)?
    public var onRequestInterception: ((URLRequest) -> Void)?
    public var onInterceptionStart: ((URLSessionTaskInterception) -> Void)?
    public var onInterceptionComplete: ((URLSessionTaskInterception) -> Void)?

    @ReadWriteLock
    public private(set) var interceptions: [UUID: URLSessionTaskInterception] = [:]

    public init(firstPartyHosts: FirstPartyHosts = .init()) {
        self.firstPartyHosts = firstPartyHosts
    }

    public func interception(for request: URLRequest) -> URLSessionTaskInterception? {
        interceptions.values.first { $0.request == request }
    }

    public func interception(for url: URL) -> URLSessionTaskInterception? {
        interceptions.values.first { $0.request.url == url }
    }

    public func modify(request: URLRequest, headerTypes: Set<TracingHeaderType>) -> URLRequest {
        onRequestMutation?(request, headerTypes)
        return modifiedRequest ?? request
    }

    public func interceptionDidStart(interception: URLSessionTaskInterception) {
        onInterceptionStart?(interception)
        interceptions[interception.identifier] = interception
    }

    public func interceptionDidComplete(interception: URLSessionTaskInterception) {
        onInterceptionComplete?(interception)
        interceptions[interception.identifier] = interception
    }
}

extension ResourceCompletion: AnyMockable {
    public static func mockAny() -> Self {
        return mockWith()
    }

    public static func mockWith(
        response: URLResponse? = .mockAny(),
        error: Error? = nil
    ) -> Self {
        return ResourceCompletion(response: response, error: error)
    }
}

extension ResourceMetrics: AnyMockable {
    public static func mockAny() -> Self {
        return mockWith()
    }

    public static func mockWith(
        fetch: DateInterval = .init(start: Date(), end: Date(timeIntervalSinceNow: 1)),
        redirection: DateInterval? = nil,
        dns: DateInterval? = nil,
        connect: DateInterval? = nil,
        ssl: DateInterval? = nil,
        firstByte: DateInterval? = nil,
        download: DateInterval? = nil,
        responseSize: Int64? = nil
    ) -> Self {
        return .init(
            fetch: fetch,
            redirection: redirection,
            dns: dns,
            connect: connect,
            ssl: ssl,
            firstByte: firstByte,
            download: download,
            responseSize: responseSize
        )
    }
}

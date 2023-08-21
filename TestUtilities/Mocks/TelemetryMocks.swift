/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import XCTest
import DatadogInternalFork

public class CoreLoggerMock: CoreLogger {
    private let queue = DispatchQueue(label: "core-logger-mock")
    public private(set) var recordedLogs: [(level: CoreLoggerLevel, message: String, error: Error?)] = []

    public init() { }

    // MARK: - CoreLogger

    public func log(_ level: CoreLoggerLevel, message: @autoclosure () -> String, error: Error?) {
        let newLog = (level, message(), error)
        queue.async { self.recordedLogs.append(newLog) }
    }

    public func reset() {
        queue.async { self.recordedLogs = [] }
    }

    // MARK: - Matching

    public typealias RecordedLog = (message: String, error: DDError?)

    private func recordedLogs(ofLevel level: CoreLoggerLevel) -> [RecordedLog] {
        return queue.sync {
            recordedLogs
                .filter({ $0.level == level })
                .map { ($0.message, $0.error.map({ DDError(error: $0) })) }
        }
    }

    public var debugLogs: [RecordedLog] { recordedLogs(ofLevel: .debug) }
    public var warnLogs: [RecordedLog] { recordedLogs(ofLevel: .warn) }
    public var errorLogs: [RecordedLog] { recordedLogs(ofLevel: .error) }
    public var criticalLogs: [RecordedLog] { recordedLogs(ofLevel: .critical) }

    public var debugLog: RecordedLog? { debugLogs.last }
    public var warnLog: RecordedLog? { warnLogs.last }
    public var errorLog: RecordedLog? { errorLogs.last }
    public var criticalLog: RecordedLog? { criticalLogs.last }
}

/// `Telemetry` recording received telemetry.
public class TelemetryMock: Telemetry, CustomStringConvertible {
    public let expectation: XCTestExpectation?

    @ReadWriteLock
    public private(set) var messages: [TelemetryMessage] = []

    @ReadWriteLock
    public private(set) var description: String = "Telemetry logs:"

    public init(expectation: XCTestExpectation? = nil) {
        self.expectation = expectation
    }

    public func send(telemetry: DatadogInternal.TelemetryMessage) {
        messages.append(telemetry)

        switch telemetry {
        case .debug(_, let message, let attributes):
            let attributesString = attributes.map({ ", \($0)" }) ?? ""
            description.append("\n- [debug] \(message)" + attributesString)
        case .error(_, let message, let kind, let stack):
            description.append("\n - [error] \(message), kind: \(kind ?? "nil"), stack: \(stack ?? "nil")")
        case .configuration(let configuration):
            description.append("\n- [configuration] \(configuration)")
        case let .metric(name, attributes):
            let attributesString = attributes.map({ "\($0.key): \($0.value)" }).joined(separator: ", ")
            description.append("\n- [metric] '\(name)' (" + attributesString + ")")
        }
    }
}

public extension Array where Element == TelemetryMessage {
    /// Returns properties of the first metric message of given name.
    func firstMetric(named metricName: String) -> (name: String, attributes: [String: Encodable])? {
        return compactMap({ $0.asMetric }).filter({ $0.name == metricName }).first
    }
}

public extension TelemetryMessage {
    /// Extracts metric attributes if this is metric message.
    var asMetric: (name: String, attributes: [String: Encodable])? {
        guard case let .metric(metricName, metricAttributes) = self else {
            return nil
        }
        return (name: metricName, attributes: metricAttributes)
    }
}

extension DD {
    /// Syntactic sugar for patching the `dd` bundle by replacing `logger`.
    ///
    /// ```
    /// let dd = DD.mockWith(logger: CoreLoggerMock())
    /// defer { dd.reset() }
    /// ```
    public static func mockWith<CL: CoreLogger>(logger: CL) -> DDMock<CL, TelemetryMock> {
        let mock = DDMock(
            oldLogger: DD.logger,
            oldTelemetry: DD.telemetry,
            logger: logger,
            telemetry: TelemetryMock()
        )
        DD.logger = logger
        return mock
    }

    /// Syntactic sugar for patching the `dd` bundle by replacing `telemetry`.
    ///
    /// ```
    /// let dd = DD.mockWith(telemetry: TelemetryMock())
    /// defer { dd.reset() }
    /// ```
    public static func mockWith<TM: Telemetry>(telemetry: TM) -> DDMock<CoreLoggerMock, TM> {
        let mock = DDMock(
            oldLogger: DD.logger,
            oldTelemetry: DD.telemetry,
            logger: CoreLoggerMock(),
            telemetry: telemetry
        )
        DD.telemetry = telemetry
        return mock
    }
}

public struct DDMock<CL: CoreLogger, TM: Telemetry> {
    let oldLogger: CoreLogger
    let oldTelemetry: Telemetry

    public let logger: CL
    public let telemetry: TM

    public func reset() {
        DD.logger = oldLogger
        DD.telemetry = oldTelemetry
    }
}

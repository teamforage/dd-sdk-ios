/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */

import Foundation

/// Encapsulates Python server configuration passed through ENV variable from  UITest runner to the app process.
struct HTTPServerMockConfiguration: Codable {
    /// Python server URL to record Logging requests.
    var logsEndpoint: URL? = nil
    /// Python server URL to record Tracing requests.
    var tracesEndpoint: URL? = nil
    /// Python server URL to record RUM requests.
    var rumEndpoint: URL? = nil

    /// Python server URLs to record custom requests, e.g. custom data requests
    /// to assert trace headers propagation.
    var instrumentedEndpoints: [URL] = []

    /// Encodes this struct to base-64 encoded string so it can be passed in ENV variable.
    var toEnvironmentValue: String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        return data.base64EncodedString()
    }

    /// Decodes this struct from base-64 encoded string so it can be read from ENV variable.
    fileprivate static func from(environmentValue: String) -> HTTPServerMockConfiguration {
        let decoder = JSONDecoder()
        let data = Data(base64Encoded: environmentValue)!
        return try! decoder.decode(HTTPServerMockConfiguration.self, from: data)
    }
}

internal struct Environment {
    struct Variable {
        static let testScenarioIdentifier = "DD_TEST_SCENARIO_IDENTIFIER"
        static let serverMockConfiguration = "DD_TEST_SERVER_MOCK_CONFIGURATION"
    }
    struct Argument {
        static let isRunningUnitTests       = "IS_RUNNING_UNIT_TESTS"
        static let isRunningUITests         = "IS_RUNNING_UI_TESTS"
        static let doNotClearPersistentData = "DO_NOT_CLEAR_PERSISTENT_DATA"
    }
    struct InfoPlistKey {
        static let clientToken      = "DatadogClientToken"
        static let rumApplicationID = "RUMApplicationID"
    }

    // MARK: - Launch Arguments

    static func isRunningUnitTests() -> Bool {
        return ProcessInfo.processInfo.arguments.contains(Argument.isRunningUnitTests)
    }

    static func isRunningUITests() -> Bool {
        return ProcessInfo.processInfo.arguments.contains(Argument.isRunningUITests)
    }

    static func shouldClearPersistentData() -> Bool {
        return !ProcessInfo.processInfo.arguments.contains(Argument.doNotClearPersistentData)
    }

    // MARK: - Launch Variables

    static func testScenario() -> TestScenario? {
        guard let envIdentifier = ProcessInfo.processInfo.environment[Variable.testScenarioIdentifier] else {
            return nil
        }

        return createTestScenario(for: envIdentifier)
    }

    static func serverMockConfiguration() -> HTTPServerMockConfiguration? {
        if let environmentValue = ProcessInfo.processInfo.environment[Variable.serverMockConfiguration] {
            return HTTPServerMockConfiguration.from(environmentValue: environmentValue)
        }
        return nil
    }

    // MARK: - Info.plist

    static func readClientToken() -> String {
        guard let clientToken = Bundle.main.infoDictionary?[InfoPlistKey.clientToken] as? String, !clientToken.isEmpty else {
            fatalError("""
            ✋⛔️ Cannot read `\(InfoPlistKey.clientToken)` from `Info.plist` dictionary.
            Please update `Datadog.xcconfig` in the repository root with your own
            client token obtained on datadoghq.com.
            You might need to run `Product > Clean Build Folder` before retrying.
            """)
        }
        return clientToken
    }

    static func readRUMApplicationID() -> String {
        guard let rumApplicationID = Bundle.main.infoDictionary![InfoPlistKey.rumApplicationID] as? String, !rumApplicationID.isEmpty else {
            fatalError("""
            ✋⛔️ Cannot read `\(InfoPlistKey.rumApplicationID)` from `Info.plist` dictionary.
            Please update `Datadog.xcconfig` in the repository root with your own
            RUM application id obtained on datadoghq.com.
            You might need to run `Product > Clean Build Folder` before retrying.
            """)
        }
        return rumApplicationID
    }
}

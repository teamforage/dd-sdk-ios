/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import DatadogTrace

@objc
public class DDTracerConfiguration: NSObject {
    internal var swiftConfiguration = DatadogTracer.Configuration()

    @objc
    override public init() {}

    // MARK: - Public

    @objc
    public func set(serviceName: String) {
        swiftConfiguration.serviceName = serviceName
    }

    @objc
    public func sendNetworkInfo(_ enabled: Bool) {
        swiftConfiguration.sendNetworkInfo = enabled
    }
}

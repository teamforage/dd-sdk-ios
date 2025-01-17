/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2020 Datadog, Inc.
 */


import Foundation
import DatadogInternalFork

extension Event: AnyMockable {
    public static func mockAny() -> Self {
        return mockWith()
    }

    public static func mockWith(data: Data = .init(), metadata: Data? = nil) -> Self {
        return Event(data: data, metadata: metadata)
    }
}

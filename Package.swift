// swift-tools-version: 5.5

import PackageDescription
import Foundation

let package = Package(
    name: "DatadogFork",
    platforms: [
        .iOS(.v11),
        .tvOS(.v11)
    ],
    products: [
        .library(
            name: "DatadogCoreFork",
            targets: ["DatadogCoreFork"]
        ),
        .library(
            name: "DatadogLogsFork",
            targets: ["DatadogLogsFork"]
        ),
    ],
    targets: [
        .target(
            name: "DatadogCoreFork",
            dependencies: [
                .target(name: "DatadogInternalFork"),
                .target(name: "DatadogPrivateFork"),
            ],
            path: "DatadogCore/Sources",
            swiftSettings: [.define("SPM_BUILD")]
        ),

        .target(
            name: "DatadogPrivateFork",
            path: "DatadogCore/Private"
        ),
        .target(
            name: "DatadogInternalFork",
            path: "DatadogInternal/Sources"
        ),
        .testTarget(
            name: "DatadogInternalTestsFork",
            dependencies: [
                .target(name: "DatadogInternalFork"),
                .target(name: "TestUtilitiesFork"),
            ],
            path: "DatadogInternal/Tests"
        ),

        .target(
            name: "DatadogLogsFork",
            dependencies: [
                .target(name: "DatadogInternalFork"),
            ],
            path: "DatadogLogs/Sources"
        ),
        .testTarget(
            name: "DatadogLogsTestsFork",
            dependencies: [
                .target(name: "DatadogLogsFork"),
                .target(name: "TestUtilitiesFork"),
            ],
            path: "DatadogLogs/Tests"
        ),

        .target(
            name: "TestUtilitiesForkFork",
            dependencies: [
                .target(name: "DatadogInternalFork"),
            ],
            path: "TestUtilities",
            sources: ["Mocks", "Helpers"]
        )
    ]
)


// If the `DD_TEST_UTILITIES_ENABLED` development ENV is set, export additional utility packages.
// To set this ENV for Xcode projects that fetch this package locally, use `open --env DD_TEST_UTILITIES_ENABLED path/to/<project or workspace>`.
if ProcessInfo.processInfo.environment["DD_TEST_UTILITIES_ENABLED"] != nil {
    package.products.append(
        .library(
            name: "TestUtilitiesFork",
            targets: ["TestUtilitiesFork"]
        )
    )
}

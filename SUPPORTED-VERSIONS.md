## Platforms

| Platform   | Supported |  Info  |
|------------|:---------:|-------:|
| **iOS**    |     ✅    |  `11+` |
| **tvOS**   |     ✅    |  `11+` |
| **iPadOS** |     ✅    |  `11+` |
| **watchOS**|     ❌    |  `n/a` |
| **macOS**  |     ❌    |  `n/a` |
| **Linux**  |     ❌    |  `n/a` |

## Xcode

SDK is build using the most recent version of Xcode, but we make sure that it's backward compatible with the [lowest supported Xcode version for AppStore submission](https://developer.apple.com/news/?id=jd9wcyov).

## Dependency Managers

We currently support integration of the SDK using following dependency managers.
- Swift Package Manager
- Cocoapods
- Carthage

## Languages

| Language        |   Version    |
|-----------------|:------------:|
| **Swift**       |     `5.*`    |
| **Objective-C** |     `2.0`    |

## UI Framework Instrumentation

| Framework       |   Automatic  | Manual |
|-----------------|:------------:|:------:|
| **UIKit**       |       ✅     |   ✅    |
| **SwiftUI**     |       ❌     |   ✅    |

## Networking Compatibility
| Framework       |   Automatic  | Manual |
|-----------------|:------------:|:------:|
| **URLSession**  |       ✅     |   ✅    |
|[**Alamofire 5+**](https://github.com/DataDog/dd-sdk-ios/tree/develop/Sources/DatadogExtensions/Alamofire) |       ❌     |   ✅    |
|  **SwiftNIO**   |       ❌     |   ❌    |

## Catalyst
We support Catalyst in build mode only.

## Dependencies
We aim to provide dependency-less SDK. Currently there is only one exception to the rule which is PLCrashReporter dependency, required by crash reporting feature.
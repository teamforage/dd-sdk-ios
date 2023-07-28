/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

import Foundation
import UIKit
import DatadogCore

internal class SendFirstPartyRequestsViewController: UIViewController {
    private var testScenario: URLSessionBaseScenario!
    private lazy var session = testScenario.getURLSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        testScenario = (appConfiguration.testScenario as! URLSessionBaseScenario)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

       callSuccessfulFirstPartyURL()
       callSuccessfulFirstPartyURLRequest()
       callBadFirstPartyURL()

        if #available(iOS 15.0, *) {
            Task {
                await callSuccessfulFirstPartyURLAsync()
                await callSuccessfulFirstPartyURLRequestAsync()
                await callBadFirstPartyURLAsync()
            }
        }
    }

    // MARK: - Tasks

    private func callSuccessfulFirstPartyURL() {
        let task = session.dataTask(with: testScenario.customGETResourceURL) { _, _, error in
            assert(error == nil)
        }
        task.resume()
    }

    private func callSuccessfulFirstPartyURLRequest() {
        let task = session.dataTask(with: testScenario.customPOSTRequest) { _, _, error in
            assert(error == nil)
        }
        task.resume()
    }

    private func callBadFirstPartyURL() {
        let task = session.dataTask(with: testScenario.badResourceURL)
        task.resume()
    }

    // MARK: - Structured Concurrency

    @available(iOS 15.0, *)
    private func callSuccessfulFirstPartyURLAsync() async {
        do {
            _ = try await session.data(from: testScenario.customGETResourceURL)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    private func callSuccessfulFirstPartyURLRequestAsync() async {
        do {
            _ = try await session.data(for: testScenario.customPOSTRequest)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @available(iOS 15.0, *)
    private func callBadFirstPartyURLAsync() async {
        _ = try? await session.data(from: testScenario.badResourceURL)
    }
}

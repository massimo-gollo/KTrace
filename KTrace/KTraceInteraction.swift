//
//  KTraceInteraction.swift
//  KTrace
//
//  Created by Massimo Gollo on 10/03/22.
//

import Foundation

/// This protocol allows to receive the tracert information.
public protocol KTraceInteraction: AnyObject {

    /// Provide the status of test
    /// - parameter running: true if the test is running, otherwise, false.
    func traceIsRunning(status: Bool)

    /// Provide the singleHop information
    /// - parameter measurement: Provide the single hop info
    func onHopReached(measurement: KTraceHopInfo)

    /// Error returned if something happen
    /// - parameter error: Error during the test.
    func error(error: NSError)
}

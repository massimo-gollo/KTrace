//
//  KTraceSettings.swift
//  KTrace
//
//  Created by Massimo Gollo on 10/03/22.
//

import Foundation

extension KTrace {

    /// Settings needed for KTraceroute
    public struct KTraceSettings {

        /// target to trace
        public let targetHost: String

        /// define max hop number
        public let maxTTL: Int

        /// max packet send for each ping to one hop
        public let probePerHop: Int

        //TODO: implement me
        /// Timeouts in seconds - not implemented
        public var timeout: Double?

        public init(targetHost: String, maxTTL: Int = 30, maxPktPerPing: Int = 3) {
            self.targetHost = targetHost
            self.maxTTL = maxTTL
            self.probePerHop = maxPktPerPing
        }
    }
}

//
//  KTraceHopMeasurement.swift
//  KTrace
//
//  Created by Massimo Gollo on 10/03/22.
//

import Foundation

///  records trace information about a single hop
///  some properties are not implemented yet
///  `sequenceNumber` hop number in path
///  `hostIP` ip of pinged hop
///  `hostName` not implemented yet
///  `reacheable` if is reacheable
///  `rtts`
///     `ttl`
public struct KTraceHopInfo: Codable {

    /// sequenceNumber of tracing. Define the hop number
    public var sequenceNumber: UInt16?

    /// hostIP is the ip of the single host (hop) pinged
    public var hostIP: String?

    /// hostName is the name of the single host (hop) pinged
    public var hostName: String?

    /// tells if host is reachable
    public var reachable: Bool?

    //TODO: Could be a dict [#pktCount : result] -> result {RTT: Double != nil if inside timeout}
    /// rrt list collected results
    public var rtt: [Double] = []

    /// current TTL for such hop
    public var ttl: Int?

    /// not implemented
    public var probeSendTIme: Date?
    /// not implemented
    public var asNumber: String?
    /// not implemented
    public var asName: String?
    /// not implemented
    public var details: KTraceInfoDetails?


    //TODO: fix types
    /// not implemented
    public struct KTraceInfoDetails: Codable {
        public var countryName: String?
        public var countryCode: String?
        public var timezone: String?
        public var region: String?
        public var city: String?
        public var lat, long: Double?
    }





}

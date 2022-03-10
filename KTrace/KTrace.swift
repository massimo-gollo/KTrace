//
//  Ktrace.swift
//  KTrace
//
//  Created by Massimo Gollo on 10/03/22.
//

import Foundation

public protocol KTraceLogger: AnyObject {
    func logTrace(_ trace: String)
}

public class KTrace: NSObject {

    /// Tune settings for KTrace
    /// Check `KTraceSettings` for more information
    public var settings: KTraceSettings


    public weak var delegate: KTraceInteraction?

    private var pinger: SimplePing?

    /// if  KTraceSettings hostname is a hostname, resolved ip is put here
    private var targetIpResolved: String?

    /// target host from settings
    private var targetHost: String

    /// maxTTL after which trance stops
    private var maxTTL: Int = 30

    private var probePerHop: Int

    private var icmpSrcAddress: String?
    private var currentTTL: Int?
    private var roundCountPerTTL: Int?
    private var sendSequence: UInt16?
    private var currentHopInfo: KTraceHopInfo?
    private var startDate: Date?
    private var sendTimer: Timer?

    /// Update KTrace status
    private var traceIsRunning: Bool = false {
        didSet {
            if traceIsRunning != oldValue {
                delegate?.traceIsRunning(status: traceIsRunning)
            }
        }
    }
    /// Initialization.
    /// - parameter settings: Contains all the settings needed for KTraceroute (`KTraceSettings`).
    public init(settings: KTraceSettings) {
        self.settings = settings
        self.targetHost = settings.targetHost
        self.maxTTL = settings.maxTTL
        self.probePerHop = settings.probePerHop
        super.init()
    }

    //TODO: should insert completation error handler?
    public func start() {
#if DEBUG
        NSLog("KTracer: start tracing")
#endif
        self.traceIsRunning.toggle()
        pinger = SimplePing(hostName: targetHost)
        pinger?.delegate = self
        pinger?.start()
    }

    public func stop(){
        sendTimer?.invalidate()
        sendTimer = nil
        pinger?.stop()
        pinger = nil

        //TODO: send in callback finished
    }

}

//implements sendPings
extension KTrace {

    func sendPing() -> Bool {
        self.currentTTL! += 1
        if self.currentTTL! > maxTTL {
            NSLog("TTL exceed the Max, stop tracing")
            stop()
            return false
        }
        sendPing(withTTL: self.currentTTL!)
        return true
    }

    func sendPing(withTTL ttl: Int) {
        roundCountPerTTL = 0

        pinger?.setTTL(Int32(ttl))
        pinger?.send()

        //setup a timer that count 3 seconds. If it isn't invalidate by receved ping pkt, means that we are in timeout
        sendTimer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(singleRoundTimeOutTrigger), userInfo: currentHopInfo, repeats: false)
    }


    @objc func singleRoundTimeOutTrigger(timer: Timer){
        guard let context = timer.userInfo as? KTraceHopInfo else {
            NSLog("context empty")
            return }
        if let hopNumber = context.sequenceNumber {
            NSLog("Hop #\(hopNumber) Timeout")
            self.currentHopInfo?.rtt.insert(-1, at: self.roundCountPerTTL!)
        } else {
            NSLog("Sequence number not set")
        }
        //move to next hop
        _ = sendPing()
    }

    func invalidSendTimer() {
        sendTimer?.invalidate()
        sendTimer = nil
    }




}


extension KTrace: SimplePingDelegate {

    /// callback, called once the object has started up.On receiving this callback, you can call  ping() to send pings.
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {

        //resolve hostname
        targetIpResolved = displayAddressForAddress(address: address as NSData)

        let msg = "Host: \(targetHost) IP: \(targetIpResolved ?? "N/D")\n"
        NSLog("KTracer: %@", msg)


        currentTTL = 1
        sendPing(withTTL: currentTTL!)
    }

    /// called if the object fails to start up. This is called shortly after you start the object to tell you that the  object has failed to start.  The most likely cause of failure is a problem  resolving `hostName`.
    public func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        //TODO: handle error in callback
        NSLog("KTracer: Error startup ping - \(error.localizedDescription)")
    }

    /// called when the object receives an unmatched ICMP message.
    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        // unexpected means that we pinged an hop != destination, so targetIP != srcAddressIntermedietHop
        assert(startDate != nil)
        //track RTT
        let interval = Date().timeIntervalSince(startDate!)
        //get src intermediate hop address
        let srcAddr = pinger.srcAddr(inIPv4Packet: packet)
        icmpSrcAddress = srcAddr

        //record Hop metric
        switch(roundCountPerTTL!){
        case 0:
            //first round - reinit temp func
            currentHopInfo = KTraceHopInfo(sequenceNumber:sendSequence, hostIP: srcAddr)
            currentHopInfo?.rtt.insert(interval, at: 0)
            self.roundCountPerTTL! += 1
        case probePerHop:
            self.delegate?.onHopReached(measurement: currentHopInfo!)
            invalidSendTimer()
            //increment TTL (next hop and repeat)
            _ = sendPing()
        default:
            currentHopInfo?.rtt.insert(interval, at: self.roundCountPerTTL!)
            self.roundCountPerTTL! += 1
        }

    }
    /// called when the object has successfully sent a ping packet.    ///
    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        //set pkt sequence number (hop number) and start a timer to count RTT
        sendSequence = sequenceNumber
        startDate = Date()
    }

    /// f the object receives an ping response that matches a ping request that it sent, it informs the delegate via this callback.
    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        invalidSendTimer()
        guard let startDate = startDate else { return }
        let interval = Date().timeIntervalSince(startDate)
        let responsedMsg = "### Host responsed, latency (ms): \(interval * 1000) ms\n"
        let receivedMsg = "#\(sequenceNumber) Data received, size=\(packet.count)\n"
        NSLog("\(responsedMsg) \n \(receivedMsg) \n")

        // Complete
        let completedMsg = "#\(sendSequence!) reach the destination \(targetHost), trace completed\n"
        NSLog("\(completedMsg)")
        //TODO: - insert last record in list - see flow of Unexpected

        stop()

    }
    /// called when the object fails to send a ping packet.
    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {

    }


}


extension KTrace {
    /// Returns the string representation of the supplied address.
    ///
    /// - parameter address: Contains a `(struct sockaddr)` with the address to render.
    ///
    /// - returns: A string representation of that address.

    func displayAddressForAddress(address: NSData) -> String {
        var hostStr = [Int8](repeating: 0, count: Int(NI_MAXHOST))

        let success = getnameinfo(
            address.bytes.assumingMemoryBound(to: sockaddr.self),
            socklen_t(address.length),
            &hostStr,
            socklen_t(hostStr.count),
            nil,
            0,
            NI_NUMERICHOST
        ) == 0
        let result: String
        if success {
            result = String(cString: hostStr)
        } else {
            result = "?"
        }
        return result
    }
}



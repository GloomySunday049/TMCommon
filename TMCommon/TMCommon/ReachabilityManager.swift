//
//  ReachabilityManager.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/19.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation
import SystemConfiguration

// MARK: ReachabilityManager

open class ReachabilityManager {
    
    public enum NetworkReabclabilityStatus {
        case unknown
        case notReachable
        case reachable(ConectionType)
    }
    
    public enum ConectionType {
        case ethernetOrWiFi
        case wwan
    }
    
    public typealias Listener = (NetworkReabclabilityStatus) -> Void
    
    // MARK: Properties
    
    open var isReachable: Bool { return isReachableOnWWAN || isReachableOnEtherOrWiFi }
    open var isReachableOnWWAN: Bool { return networkReachabilityStatus == .reachable(.wwan) }
    open var isReachableOnEtherOrWiFi: Bool { return networkReachabilityStatus == .reachable(.ethernetOrWiFi) }
    open var networkReachabilityStatus: NetworkReabclabilityStatus {
        guard let flags = self.flags else { return .unknown }
        return networkReachabilityStatusForFlags(flags)
    }
    open var listenerQueue: DispatchQueue = DispatchQueue.main
    open var listener: Listener?
    
    private let reachability: SCNetworkReachability
    private var previousFlags: SCNetworkReachabilityFlags
    
    private var flags: SCNetworkReachabilityFlags? {
        var flags = SCNetworkReachabilityFlags()
        if SCNetworkReachabilityGetFlags(reachability, &flags) {
            return flags
        }
        
        return nil
    }
    
    // MARK: Initialization
    
    public convenience init?(host: String) {
        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host) else { return nil }
        self.init(reachability: reachability)
    }
    
    public convenience init?() {
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        guard let reachability = withUnsafePointer(to: &address, { pointer in
            return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                return SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return nil }
        
        self.init(reachability: reachability)
    }
    
    private init(reachability: SCNetworkReachability) {
        self.reachability = reachability
        self.previousFlags = SCNetworkReachabilityFlags()
    }
    
    deinit {
        stopListening()
    }
    
    // MARK: Listening 
    
    @discardableResult
    open func startListening() -> Bool {
        var context  = SCNetworkReachabilityContext(version: 0, info: nil, retain: nil, release: nil, copyDescription: nil)
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let callbackEnabled = SCNetworkReachabilitySetCallback(reachability, { _, flags, info in
                let reachability = Unmanaged<ReachabilityManager>.fromOpaque(info!).takeUnretainedValue()
                reachability.notifyListener(flags)
            }, &context)
        let queueEnabled = SCNetworkReachabilitySetDispatchQueue(reachability, listenerQueue)
        listenerQueue.async {
            self.previousFlags = SCNetworkReachabilityFlags()
            self.notifyListener(self.flags ?? SCNetworkReachabilityFlags())
        }
        
        return callbackEnabled && queueEnabled
    }
    
    open func stopListening() {
        SCNetworkReachabilitySetCallback(reachability, nil, nil)
        SCNetworkReachabilitySetDispatchQueue(reachability, nil)
    }
    
    // MARK: Internal - Listener Notification
    
    func notifyListener(_ flags: SCNetworkReachabilityFlags) {
        guard previousFlags != flags else { return }
        previousFlags = flags
        listener?(networkReachabilityStatusForFlags(flags))
    }
    
    // MARK: Internal - Network Reachability Status
    
    func networkReachabilityStatusForFlags(_ flags: SCNetworkReachabilityFlags) -> NetworkReabclabilityStatus {
        guard flags.contains(.reachable) else { return .notReachable }
        var networkStatus: NetworkReabclabilityStatus = .notReachable
        if !flags.contains(.connectionRequired) { networkStatus = .reachable(.ethernetOrWiFi) }
        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            if !flags.contains(.interventionRequired) { networkStatus = .reachable(.ethernetOrWiFi) }
        }
            
        #if os(iOS)
            if flags.contains(.isWWAN) { networkStatus = .reachable(.wwan) }
        #endif
            
        return networkStatus
    }
}

extension ReachabilityManager.NetworkReabclabilityStatus: Equatable {}

public func ==(lhs: ReachabilityManager.NetworkReabclabilityStatus, rhs: ReachabilityManager.NetworkReabclabilityStatus) -> Bool {
    switch (lhs, rhs) {
    case (.unknown, .unknown):
        return true
    case (.notReachable, .notReachable):
        return true
    case let (.reachable(lhsConnectionType), .reachable(rhsConnectionType)):
        return lhsConnectionType == rhsConnectionType
    default:
        return false
    }
}

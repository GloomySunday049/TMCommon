//
//  ServerTrustPolicy.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: ServerTrustPolicyManager

open class ServerTrustPolicyManager {
    open let policies: [String : ServerTrustPolicy]
    
    public init(policies: [String : ServerTrustPolicy]) {
        self.policies = policies
    }
    
    open func serverTrustPolicy(forHost host: String) -> ServerTrustPolicy? {
        return policies[host]
    }
}

extension URLSession {
    
    private struct AssociatedKeys {
        static var managerKey = "NT.URLSession.ServerTrustPolicyManager"
    }
    
    var serverTrustPolicyManager: ServerTrustPolicyManager? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.managerKey) as? ServerTrustPolicyManager
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.managerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: ServerTrustPolicy

public enum ServerTrustPolicy {
    
    case performDefaultEvaluation(validateHost: Bool)
    case pinCertificates(certificates: [SecCertificate], validateCertificateChain: Bool, validateHost: Bool)
    case pinPublicKeys(publicKeys: [SecKey], validateCertificateChain: Bool, validateHost: Bool)
    case disableEvaluation
    case customEvaluation((_ serverTrust: SecTrust, _ host: String) -> Bool)
    
    public static func certificates(in bundle: Bundle = Bundle.main) -> [SecCertificate] {
        var certificates: [SecCertificate] = []
        let paths = Set([".cer", ".CER", ".crt", ".CRT", ".der", ".DER"].map {
            bundle.paths(forResourcesOfType: $0, inDirectory: nil)
            }.joined())
        
        for path in paths {
            if let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) as CFData, let certificate = SecCertificateCreateWithData(nil, certificateData) {
                certificates.append(certificate)
            }
        }
        
        return certificates
    }
    
    public static func publicKeys(in bundle: Bundle = Bundle.main) -> [SecKey] {
        var publicKeys: [SecKey] = []
        for certificate in certificates(in: bundle) {
            if let publicKey = publicKey(for: certificate) {
                publicKeys.append(publicKey)
            }
        }
        
        return publicKeys
    }
    
    public func evalute(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        var serverTrustIsValid = false
        switch self {
        case let .performDefaultEvaluation(validateHost):
            let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
            SecTrustSetPolicies(serverTrust, policy)
            serverTrustIsValid = trustIsValid(serverTrust)
        case let .pinCertificates(pinnedCertificates, validateCertificateChain, validateHost):
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, policy)
                SecTrustSetAnchorCertificates(serverTrust, pinnedCertificates as CFArray)
                SecTrustSetAnchorCertificatesOnly(serverTrust, true)
                serverTrustIsValid = trustIsValid(serverTrust)
            } else {
                let serverCertificatesDataArray = certificateData(for: serverTrust)
                let pinnedCertificatesDataArray = certificateData(for: pinnedCertificates)
                outerloop: for serverCertificateData in serverCertificatesDataArray {
                    for pinnedCertificateData in pinnedCertificatesDataArray {
                        if serverCertificateData == pinnedCertificateData {
                            serverTrustIsValid = true
                            break outerloop
                        }
                    }
                }
            }
        case let .pinPublicKeys(pinnedPublicKeys, validateCertificateChain, validateHost):
            var certificateChainEvaliationPassed = true
            if validateCertificateChain {
                let policy = SecPolicyCreateSSL(true, validateHost ? host as CFString : nil)
                SecTrustSetPolicies(serverTrust, policy)
                certificateChainEvaliationPassed = trustIsValid(serverTrust)
            }
            
            if certificateChainEvaliationPassed {
                outerLoop: for serverPublicKey in ServerTrustPolicy.publicKeys(for: serverTrust) as [AnyObject] {
                    for pinnedPublicKey in pinnedPublicKeys as [AnyObject] {
                        if serverPublicKey.isEqual(pinnedPublicKey) {
                            serverTrustIsValid = true
                            break outerLoop
                        }
                    }
                }
            }
        case .disableEvaluation:
            serverTrustIsValid = true
        case let .customEvaluation(closure):
            serverTrustIsValid = closure(serverTrust, host)
        }
        
        return serverTrustIsValid
    }
    
    // MARK: Private
    
    private func trustIsValid(_ trust: SecTrust) -> Bool {
        var isValid = false
        var result = SecTrustResultType.invalid
        let status = SecTrustEvaluate(trust, &result)
        if status == errSecSuccess {
            let unspecified = SecTrustResultType.unspecified
            let proceed = SecTrustResultType.proceed
            isValid = result == unspecified || result == proceed
        }
        
        return isValid
    }
    
    private func certificateData(for trust: SecTrust) -> [Data] {
        var certificates: [SecCertificate] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index) {
                certificates.append(certificate)
            }
        }
        
        return certificateData(for: certificates)
    }
    
    private func certificateData(for certificates: [SecCertificate]) -> [Data] {
        return certificates.map { SecCertificateCopyData($0) as Data }
    }
    
    private static func publicKeys(for trust: SecTrust) -> [SecKey] {
        var publicKeys: [SecKey] = []
        for index in 0..<SecTrustGetCertificateCount(trust) {
            if let certificate = SecTrustGetCertificateAtIndex(trust, index), let publicKey = publicKey(for: certificate) {
                publicKeys.append(publicKey)
            }
        }
        
        return publicKeys
    }
    
    private static func publicKey(for certificate: SecCertificate) -> SecKey? {
        var publicKey: SecKey?
        let policy = SecPolicyCreateBasicX509()
        var trust: SecTrust?
        let trustCreationStatus = SecTrustCreateWithCertificates(certificate, policy, &trust)
        if let trust = trust, trustCreationStatus == errSecSuccess {
            publicKey = SecTrustCopyPublicKey(trust)
        }
        
        return publicKey
    }
}

//
//  Validation.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/19.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension Request {
    
    fileprivate typealias ErrorReasion = NTError.ResponseValidationFailureReason
    
    public enum ValidationResult {
        
        case success
        case failure(Error)
    }
    
    fileprivate struct MIMEType {
        
        let type: String
        let subtype: String
        var isWildcard: Bool { return type == "*" && subtype == "*" }
        
        init?(_ string: String) {
            let components: [String] = {
                let stripped = string.trimmingCharacters(in: .whitespacesAndNewlines)
                let split = stripped.substring(to: stripped.range(of: ";")?.lowerBound ?? stripped.endIndex)
                return split.components(separatedBy: "/")
            }()
            
            if let type = components.first, let subtype = components.last {
                self.type = type
                self.subtype = subtype
            } else {
                return nil
            }
        }
        
        func matches(_ mime: MIMEType) -> Bool {
            switch (type, subtype) {
            case (mime.type, mime.subtype), (mime.type, "*"), ("*", mime.subtype), ("*","*"):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: Properties
    
    fileprivate var acceptableStatusCodes: [Int] { return Array(200..<300) }
    fileprivate var acceptableContentTypes: [String] {
        if let accept = request?.value(forHTTPHeaderField: "Accept") {
            return accept.components(separatedBy: ",")
        }
        
        return ["*/*"]
    }
    
    // MARK: Status Code
    
    fileprivate func validate<S: Sequence>(statusCode acceptableStatusCodes: S, response: HTTPURLResponse) -> ValidationResult where S.Iterator.Element == Int {
        if acceptableStatusCodes.contains(response.statusCode) {
            return .success
        } else {
            let reason: ErrorReasion = .unacceptableStatusCode(code: response.statusCode)
            return .failure(NTError.responseValidationFailed(reason: reason))
        }
    }
    
    // MARK: Content Type
    
    fileprivate func validate<S: Sequence>(contentType acceptableContentTypes: S, response: HTTPURLResponse, data: Data?) -> ValidationResult where S.Iterator.Element == String {
        guard let data = data, data.count > 0 else { return .success }
        guard let responseContentType = response.mimeType, let responseMIMEType = MIMEType(responseContentType) else {
            for contentType in acceptableContentTypes {
                if let mimeType = MIMEType(contentType), mimeType.isWildcard {
                    return .success
                }
            }
            
            let error: NTError = {
                let reason: ErrorReasion = .missingContentType(acceptableContentTypes: Array(acceptableContentTypes))
                return NTError.responseValidationFailed(reason: reason)
            }()
            
            return .failure(error)
        }
        
        for contentType in acceptableContentTypes {
            if let acceptableMIMEType = MIMEType(contentType), acceptableMIMEType.matches(responseMIMEType) {
                return .success
            }
        }
        
        let error: NTError = {
            let reason: ErrorReasion = .unacceptableContentType(acceptableContentTypes: Array(acceptableContentTypes), responseContentType: responseContentType)
            return NTError.responseValidationFailed(reason: reason)
        }()
        
        return .failure(error)
    }
}

extension DataRequest {
    
    public typealias Validation = (URLRequest?, HTTPURLResponse, Data?) -> ValidationResult
    
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            if let response = self.response, self.delegate.error == nil, case let .failure(error) = validation(self.request, response, self.delegate.data) {
                self.delegate.error = error
            }
        }
        
        validations.append(validationExecution)
        return self
    }
    
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Self where S.Iterator.Element == String {
        return validate { [unowned self] _, response, data in
            return self.validate(contentType: acceptableContentTypes, response: response, data: data)
        }
    }
    
    @discardableResult
    public func validate() -> Self {
        return validate(statusCode: self.acceptableStatusCodes).validate(contentType: self.acceptableContentTypes)
    }
}

extension DownloadRequest {
    
    public typealias Validation = (_ request: URLRequest?, _ response: HTTPURLResponse, _ tempoarayURL: URL?, _ destinationURL: URL?) -> ValidationResult
    
    @discardableResult
    public func validate(_ validation: @escaping Validation) -> Self {
        let validationExecution: () -> Void = { [unowned self] in
            let request = self.request
            let temporaryURL = self.downloadDelegate.temporaryURL
            let destinationURL = self.downloadDelegate.destinationURL
            if let response = self.response, self.delegate.error == nil, case let .failure(error) = validation(request, response, temporaryURL, destinationURL) {
                self.delegate.error = error
            }
        }
        
        validations.append(validationExecution)
        
        return self
    }
    
    @discardableResult
    public func validate<S: Sequence>(statusCode acceptableStatusCodes: S) -> Self where S.Iterator.Element == Int {
        return validate { [unowned self] _, response, _, _ in
            return self.validate(statusCode: acceptableStatusCodes, response: response)
        }
    }
    
    @discardableResult
    public func validate<S: Sequence>(contentType acceptableContentTypes: S) -> Self where S.Iterator.Element == String {
        return validate { [unowned self] _, response, _, _ in
            let fileURL = self.downloadDelegate.fileURL
            guard let validFileURL = fileURL else {
                return .failure(NTError.responseValidationFailed(reason: .dataFileNil))
            }
            
            do {
                let data = try Data(contentsOf: validFileURL)
                return self.validate(contentType: acceptableContentTypes, response: response, data: data)
            } catch {
                return .failure(NTError.responseValidationFailed(reason: .dataFileReadFailed(at: validFileURL)))
            }
        }
    }
    
    @discardableResult
    public func validate() -> Self {
        return validate(statusCode: self.acceptableStatusCodes).validate(contentType: self.acceptableContentTypes)
    }
}

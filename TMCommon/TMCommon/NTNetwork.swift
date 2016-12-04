//
//  NTNetwork.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/15.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: URLConvertible

public protocol URLConvertible {
    func asURL() throws -> URL
}

extension String: URLConvertible {
    
    public func asURL() throws -> URL {
        guard let url = URL(string: self)  else {
            throw NTError.invalidURL(url: self)
        }
        
        return url
    }
}

extension URL: URLConvertible {
    
    public func asURL() throws -> URL {
        return self
    }
}

extension URLComponents: URLConvertible {
    
    public func asURL() throws -> URL {
        guard let url = url else {
            throw NTError.invalidURL(url: self)
        }
        
        return url
    }
}

// MARK: URLRequestConvertible

public protocol URLRequestConvertible {
    
    func asURLRequest() throws -> URLRequest
}

extension URLRequestConvertible {
    
    public var urlRequest: URLRequest? {
        return try? asURLRequest()
    }
}

extension URLRequest: URLRequestConvertible {
    
    public func asURLRequest() throws -> URLRequest {
        return self
    }
}

// MARK: URLRequest Extension

extension URLRequest {
    
    public init(url: URLConvertible, method: HTTPMethod, headers: HTTPHeaders? = nil) throws {
        let url = try url.asURL()
        self.init(url: url)
        httpMethod = method.rawValue
        if let headers = headers {
            for (headerField, headerValue) in headers {
                setValue(headerValue, forHTTPHeaderField: headerField)
            }
        }
    }
    
    func adapt(using adapter: RequestAdapter?) throws -> URLRequest {
        guard let adapter = adapter else { return self }
        return try adapter.adapt(self)
    }
}

// MARK: Data Request Methods

@discardableResult
public func _data(_ url: URLConvertible,
                method: HTTPMethod = .get,
                parameters: Parameters? = nil,
                encoding: ParamterEncoding = URLEncoding.default,
                headers: HTTPHeaders? = nil) -> DataRequest {
    return SessionManager.default.request(url, method: method, parameters: parameters, encoding: encoding, headers: headers)
}

@discardableResult
public func _data(_ urlRequest: URLRequestConvertible) -> DataRequest {
    return SessionManager.default.request(urlRequest)
}

// MARK: Download Request Methods

@discardableResult
public func _download(_ url: URLConvertible,
                      method: HTTPMethod = .get,
                      parameters: Parameters? = nil,
                      encoding: ParamterEncoding = URLEncoding.default,
                      headers: HTTPHeaders? = nil,
                      to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(url, method: method, parameters: parameters, encoding: encoding, headers: headers, to: destination)
}

@discardableResult
public func _download(_ urlRequest: URLRequestConvertible, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(urlRequest, to: destination)
}

// MARK: Download Resume Methods

@discardableResult
public func _download(resumingWith resumeData: Data, to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
    return SessionManager.default.download(resumingWith: resumeData, to: destination)
}

// MARK: Upload Methods

@discardableResult
public func _upload(_ fileURL: URL,
                    to url: URLConvertible,
                    method: HTTPMethod = .post,
                    headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(fileURL, to: url, method: method, headers: headers)
}

@discardableResult
public func _upload(_ fileURL: URL, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(fileURL, with: urlRequest)
}

@discardableResult
public func _upload(_ data: Data,
                    to url: URLConvertible,
                    method: HTTPMethod = .post,
                    headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(data, to: url, method: method, headers: headers)
}

@discardableResult
public func _upload(_ data: Data, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(data, with: urlRequest)
}

@discardableResult
public func _upload(_ stream: InputStream,
                    to url: URLConvertible,
                    method: HTTPMethod = .post,
                    headers: HTTPHeaders? = nil) -> UploadRequest {
    return SessionManager.default.upload(stream, to: url, method: method, headers: headers)
}

@discardableResult
public func _upload(_ stream: InputStream, with urlRequest: URLRequestConvertible) -> UploadRequest {
    return SessionManager.default.upload(stream, with: urlRequest)
}

public func _upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                    usingThreshold encodingMemeoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshould,
                    to url: URLConvertible,
                    method: HTTPMethod = .post,
                    headers: HTTPHeaders? = nil,
                    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?) {
    return SessionManager.default.upload(multipartFormData: multipartFormData, usingThreshold: encodingMemeoryThreshold, to: url, method: method, headers: headers, encodingCompletion: encodingCompletion)
}

public func _upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                    usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshould,
                    with urlRequest: URLRequestConvertible,
                    encodingCompletion: ((SessionManager.MultipartFormDataEncodingResult) -> Void)?) {
    return SessionManager.default.upload(multipartFormData: multipartFormData, usingThreshould: encodingMemoryThreshold, with: urlRequest, encodingCompletion: encodingCompletion)
}

//// MARK: - Stream Request
//
//@discardableResult
//public func stream(withHostName hostName: String, port: Int) -> StreamRequest {
//    return SessionManager.default.stream(withHostName: hostName, port: port)
//}
//
//@discardableResult
//public func stream(with netService: NetService) -> StreamRequest {
//    return SessionManager.default.stream(with: netService)
//}

//
//  ResponseSerialization.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/18.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: -

public protocol DataResponseSerializerProtocol {
    
    associatedtype SerializedObject
    
    var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<SerializedObject> { get }
}

// MARK: -

public struct DataRepsonseSerializer<Value>: DataResponseSerializerProtocol {
    
    public typealias SerializedObject = Value
    
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>
    
    public init(serializeResponse: @escaping (URLRequest?, HTTPURLResponse?, Data?, Error?) -> Result<Value>) {
        self.serializeResponse = serializeResponse
    }
}

// MARK: -

public protocol DownloadResponseSerializerProtocol {
    
    associatedtype SerializedObject
    
    var serializeResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<SerializedObject> { get }
}

// MARK: -

public struct DownloadResponseSerializer<Value> : DownloadResponseSerializerProtocol {
 
    public typealias SerializedObject = Value
    
    public var serializeResponse: (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>
    
    public init(serializeResponse: @escaping (URLRequest?, HTTPURLResponse?, URL?, Error?) -> Result<Value>) {
        self.serializeResponse = serializeResponse
    }
}

// MARK: -

extension DataRequest {
    
    @discardableResult
    public func response(queue: DispatchQueue? = nil, completionHandler: @escaping (DefaultDataResponse) -> Void) -> Self {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var dataResponse = DefaultDataResponse(request: self.request, response: self.response, data: self.delegate.data, error: self.delegate.error)
                dataResponse.add(self.delegate.metrics)
                completionHandler(dataResponse)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func response<T: DataResponseSerializerProtocol>(queue: DispatchQueue? = nil, responseSerializer: T, completionHandler: @escaping (DataResponse<T.SerializedObject>) -> Void) -> Self {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(self.request, self.response, self.delegate.data, self.delegate.error)
            let requestCompletedTime = self.endTime ?? CFAbsoluteTimeGetCurrent()
            let initialResponseTime = self.delegate.initialResponseTime ?? requestCompletedTime
            let timeline = Timeline(requestStartTime: self.startTime ?? CFAbsoluteTimeGetCurrent(),
                                    initialResponseTime: initialResponseTime,
                                    requestCompletedTime: requestCompletedTime,
                                    serializationCompletedTime: CFAbsoluteTimeGetCurrent())
            var dataResponse = DataResponse<T.SerializedObject>(request: self.request,
                                                                response: self.response,
                                                                data: self.delegate.data,
                                                                result: result,
                                                                timeline: timeline)
            dataResponse.add(self.delegate.metrics)
            (queue ?? DispatchQueue.main).async { completionHandler(dataResponse) }
        }
        
        return self
    }
}

extension DownloadRequest {
    
    @discardableResult
    public func response(queue: DispatchQueue? = nil, completionHandler: @escaping (DefaultDownloadResponse) -> Void) -> Self {
        delegate.queue.addOperation {
            (queue ?? DispatchQueue.main).async {
                var downloadResponse = DefaultDownloadResponse(request: self.request,
                                                               response: self.response,
                                                               temporaryURL: self.downloadDelegate.temporaryURL,
                                                               destinationURL: self.downloadDelegate.destinationURL,
                                                               resumeData: self.downloadDelegate.resumeData,
                                                               error: self.downloadDelegate.error)
                downloadResponse.add(self.delegate.metrics)
                completionHandler(downloadResponse)
            }
        }
        
        return self
    }
    
    @discardableResult
    public func response<T: DownloadResponseSerializerProtocol>(queue: DispatchQueue? = nil, responseSerializer: T, completetionHandler: @escaping (DownloadResponse<T.SerializedObject>) -> Void) -> Self {
        delegate.queue.addOperation {
            let result = responseSerializer.serializeResponse(self.request, self.response, self.downloadDelegate.fileURL, self.downloadDelegate.error)
            let requestCompletedTime = self.endTime ?? CFAbsoluteTimeGetCurrent()
            let initialResponseTime = self.delegate.initialResponseTime ?? requestCompletedTime
            let timeline = Timeline(requestStartTime: self.startTime ?? CFAbsoluteTimeGetCurrent(),
                                    initialResponseTime: initialResponseTime,
                                    requestCompletedTime: requestCompletedTime,
                                    serializationCompletedTime: CFAbsoluteTimeGetCurrent())
            var downloadResponse = DownloadResponse<T.SerializedObject>(request: self.request,
                                                                        response: self.response,
                                                                        temporaryURL: self.downloadDelegate.temporaryURL,
                                                                        destinationURL: self.downloadDelegate.destinationURL,
                                                                        resumeData: self.downloadDelegate.resumeData,
                                                                        result: result,
                                                                        timeline: timeline)
            downloadResponse.add(self.delegate.metrics)
            (queue ?? DispatchQueue.main).async { completetionHandler(downloadResponse) }
        }
        
        return self
    }
}

// MARK: - Data

extension Request {
    
    public static func serializeResponseData(response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<Data> {
        guard error == nil else { return .failure(error!) }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(Data()) }
        guard let validData = data else {
            return .failure(NTError.responseSerializationFailed(reason: .inputDataNil))
        }
        
        return .success(validData)
    }
}

extension DataRequest {
    
    public static func dataResponseSerializer() -> DataRepsonseSerializer<Data> {
        return DataRepsonseSerializer { return Request.serializeResponseData(response: $0.1, data: $0.2, error: $0.3) }
    }
    
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil, completionHandler: @escaping (DataResponse<Data>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.dataResponseSerializer(), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    
    public static func dataResponseSerializer() -> DownloadResponseSerializer<Data> {
        return DownloadResponseSerializer {
            guard $0.3 == nil else { return .failure($0.3!) }
            guard let fileURL = $0.2 else {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseData(response: $0.1, data: data, error: $0.3)
            } catch {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responseData(queue: DispatchQueue? = nil, completionHandler: @escaping (DownloadResponse<Data>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.dataResponseSerializer(), completetionHandler: completionHandler)
    }
}

// MARK: - String

extension Request {
    
    public static func serializeResponseString(encoding: String.Encoding?,
                                               response: HTTPURLResponse?,
                                               data: Data?,
                                               error: Error?) -> Result<String> {
        guard error == nil else { return .failure(error!) }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success("") }
        guard let validData = data else {
            return .failure(NTError.responseSerializationFailed(reason: .inputDataNil))
        }
        
        var convertedEncoding = encoding
        if let encodingName = response?.textEncodingName as CFString!, convertedEncoding == nil {
            convertedEncoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding(encodingName)))
        }
        
        let actualEncoding = convertedEncoding ?? String.Encoding.isoLatin1
        if let string = String(data: validData, encoding: actualEncoding) {
            return .success(string)
        } else {
            return .failure(NTError.responseSerializationFailed(reason: .stringSerializationFailed(encoding: actualEncoding)))
        }
    }
}

extension DataRequest {
    
    public static func stringResponseSerializer(encoding: String.Encoding? = nil) -> DataRepsonseSerializer<String> {
        return DataRepsonseSerializer {
            return Request.serializeResponseString(encoding: encoding, response: $0.1, data: $0.2, error: $0.3)
        }
    }
    
    @discardableResult
    public func responseString(queue: DispatchQueue? = nil,
                               encoding: String.Encoding? = nil,
                               completionHandler: @escaping (DataResponse<String>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.stringResponseSerializer(), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    
    public static func stringResponseSerializer(encoding: String.Encoding? = nil) -> DownloadResponseSerializer<String> {
        return DownloadResponseSerializer {
            guard $0.3 == nil else { return .failure($0.3!) }
            guard let fileURL = $0.2 else {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseString(encoding: encoding, response: $0.1, data: data, error: $0.3)
            } catch {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responseString(queue: DispatchQueue? = nil,
                               encoding: String.Encoding? = nil,
                               completionHandler: @escaping (DownloadResponse<String>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.stringResponseSerializer(encoding: encoding), completetionHandler: completionHandler)
    }
}

// MARK: Model - JSON

extension Request {
    
    public static func serializeResponseModel<T: TMJSON>(options: JSONSerialization.ReadingOptions, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T?> {
        guard error == nil else { return .failure(error!) }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(nil) }
        guard let validData = data, validData.count > 0 else {
            return .failure(NTError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        if let jsonString = String(data: validData, encoding: String.Encoding.utf8) {
            return .success(JSONDeserializer<T>.deserializeFrom(json: jsonString))
        } else {
            return .failure(NTError.responseSerializationFailed(reason: .jsonModelSerializationFailed))
        }
    }
}

extension DataRequest {
    
    public static func jsonModelResponseSerializer<T: TMJSON>(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataRepsonseSerializer<T?> {
        return DataRepsonseSerializer {
            return Request.serializeResponseModel(options: options, response: $0.1, data: $0.2, error: $0.3)
        }
    }
    
    @discardableResult
    public func responseModel<T: TMJSON>(queue: DispatchQueue? = nil,
                              options: JSONSerialization.ReadingOptions = .allowFragments,
                              completionHandler: @escaping (DataResponse<T?>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.jsonModelResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

// MARK: - JSON

extension Request {
    
    public static func serializeResponseJSON(options: JSONSerialization.ReadingOptions,
                                             response: HTTPURLResponse?,
                                             data: Data?,
                                             error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(NSNull()) }
        guard let validData = data, validData.count > 0 else {
            return .failure(NTError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: validData, options: options)
            return .success(json)
        } catch {
            return .failure(NTError.responseSerializationFailed(reason: .jsonSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    
    public static func jsonResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataRepsonseSerializer<Any> {
        return DataRepsonseSerializer {
            return Request.serializeResponseJSON(options: options, response: $0.1, data: $0.2, error: $0.3)
        }
    }
    
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.jsonResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    
    public static func jsonResponseSerializer(options: JSONSerialization.ReadingOptions = .allowFragments) -> DownloadResponseSerializer<Any> {
        return DownloadResponseSerializer {
            guard $0.3 == nil else { return .failure($0.3!) }
            guard let fileURL = $0.2 else {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponseJSON(options: options, response: $0.1, data: data, error: $0.3)
            } catch {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responseJSON(queue: DispatchQueue? = nil,
                             options: JSONSerialization.ReadingOptions = .allowFragments,
                             completionHandler: @escaping (DownloadResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.jsonResponseSerializer(options: options), completetionHandler: completionHandler)
    }
}

// MARK: - Property List

extension Request {
    
    public static func serializeResponsePropertyList(options: PropertyListSerialization.ReadOptions,
                                                     response: HTTPURLResponse?,
                                                     data: Data?,
                                                     error: Error?) -> Result<Any> {
        guard error == nil else { return .failure(error!) }
        if let response = response, emptyDataStatusCodes.contains(response.statusCode) { return .success(NSNull()) }
        guard let validData = data, validData.count > 0 else {
            return .failure(NTError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        do {
            let plist = try  PropertyListSerialization.propertyList(from: validData, options: options, format: nil)
            return .success(plist)
        } catch {
            return .failure(NTError.responseSerializationFailed(reason: .propertyListSerializationFailed(error: error)))
        }
    }
}

extension DataRequest {
    
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = []) -> DataRepsonseSerializer<Any> {
        return DataRepsonseSerializer {
            return Request.serializeResponsePropertyList(options: options, response: $0.1, data: $0.2, error: $0.3)
        }
    }
    
    @discardableResult
    public func responsePropertyList(queue: DispatchQueue? = nil,
                                     options: PropertyListSerialization.ReadOptions = [],
                                     completionHandler: @escaping (DataResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.propertyListResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

extension DownloadRequest {
    
    public static func propertyListResponseSerializer(options: PropertyListSerialization.ReadOptions = []) -> DownloadResponseSerializer<Any> {
        return DownloadResponseSerializer {
            guard $0.3 == nil else { return .failure($0.3!) }
            guard let fileURL = $0.2 else {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileNil))
            }
            
            do {
                let data = try Data(contentsOf: fileURL)
                return Request.serializeResponsePropertyList(options: options, response: $0.1, data: data, error: $0.3)
            } catch {
                return .failure(NTError.responseSerializationFailed(reason: .inputFileReadFailed(at: fileURL)))
            }
        }
    }
    
    @discardableResult
    public func responsePropertyList(queue: DispatchQueue? = nil,
                                     options: PropertyListSerialization.ReadOptions = [],
                                     completionHandler: @escaping (DownloadResponse<Any>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DownloadRequest.propertyListResponseSerializer(options: options), completetionHandler: completionHandler)
    }
}

private let emptyDataStatusCodes: Set<Int> = [204, 205]

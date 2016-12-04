//
//  Response.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/18.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: DefaultDataResponse

public struct DefaultDataResponse {
    
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let error: Error?
    
    var _metrics: AnyObject?
    
    init(request: URLRequest?, response: HTTPURLResponse?, data: Data?, error: Error?) {
        self.request = request
        self.response = response
        self.data = data
        self.error = error
    }
}

// MARK: DataResponse

public struct DataResponse<Value> {
    
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let data: Data?
    public let result: Result<Value>
    public let timeline: Timeline
    
    var _metrics: AnyObject?
    
    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        data: Data?,
        result: Result<Value>,
        timeline: Timeline = Timeline())
    {
        self.request = request
        self.response = response
        self.data = data
        self.result = result
        self.timeline = timeline
    }
}

// MARK: DataResponse

extension DataResponse: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return result.debugDescription
    }
    
    public var debugDescription: String {
        var output: [String] = []
        
        output.append(request != nil ? "[Request]: \(request!)" : "[Request]: nil")
        output.append(response != nil ? "[Response]: \(response!)" : "[Response]: nil")
        output.append("[Data]: \(data?.count ?? 0) bytes")
        output.append("[Result]: \(result.debugDescription)")
        output.append("[Timeline]: \(timeline.debugDescription)")
        
        return output.joined(separator: "\n")
    }
}

// MARK: DefaultDownloadResponse

public struct DefaultDownloadResponse {
    
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let temporaryURL: URL?
    public let destinationURL: URL?
    public let resumeData: Data?
    public let error: Error?
    
    var _metrics: AnyObject?
    
    init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        temporaryURL: URL?,
        destinationURL: URL?,
        resumeData: Data?,
        error: Error?)
    {
        self.request = request
        self.response = response
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        self.resumeData = resumeData
        self.error = error
    }
}

// MARK: DownloadResponse

public struct DownloadResponse<Value> {
    
    public let request: URLRequest?
    public let response: HTTPURLResponse?
    public let temporaryURL: URL?
    public let destinationURL: URL?
    public let resumeData: Data?
    public let result: Result<Value>
    public let timeline: Timeline
    
    var _metrics: AnyObject?
    
    public init(
        request: URLRequest?,
        response: HTTPURLResponse?,
        temporaryURL: URL?,
        destinationURL: URL?,
        resumeData: Data?,
        result: Result<Value>,
        timeline: Timeline = Timeline())
    {
        self.request = request
        self.response = response
        self.temporaryURL = temporaryURL
        self.destinationURL = destinationURL
        self.resumeData = resumeData
        self.result = result
        self.timeline = timeline
    }
}

// MARK: DownloadResponse

extension DownloadResponse: CustomStringConvertible, CustomDebugStringConvertible {
    
    public var description: String {
        return result.debugDescription
    }
    
    public var debugDescription: String {
        var output: [String] = []
        
        output.append(request != nil ? "[Request]: \(request!)" : "[Request]: nil")
        output.append(response != nil ? "[Response]: \(response!)" : "[Response]: nil")
        output.append("[TemporaryURL]: \(temporaryURL?.path ?? "nil")")
        output.append("[DestinationURL]: \(destinationURL?.path ?? "nil")")
        output.append("[ResumeData]: \(resumeData?.count ?? 0) bytes")
        output.append("[Result]: \(result.debugDescription)")
        output.append("[Timeline]: \(timeline.debugDescription)")
        
        return output.joined(separator: "\n")
    }
}

// MARK: Response 

protocol Response {
    /// The task metrics containing the request / response statistics.
    var _metrics: AnyObject? { get set }
    mutating func add(_ metrics: AnyObject?)
}

extension Response {
    mutating func add(_ metrics: AnyObject?) {
        #if !os(watchOS)
            guard #available(iOS 10.0, macOS 10.12, tvOS 10.0, *) else { return }
            guard let metrics = metrics as? URLSessionTaskMetrics else { return }
            
            _metrics = metrics
        #endif
    }
}

// MARK: -

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension DefaultDataResponse: Response {
    #if !os(watchOS)
    /// The task metrics containing the request / response statistics.
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension DataResponse: Response {
    #if !os(watchOS)
    /// The task metrics containing the request / response statistics.
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension DefaultDownloadResponse: Response {
    #if !os(watchOS)
    /// The task metrics containing the request / response statistics.
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

@available(iOS 10.0, macOS 10.12, tvOS 10.0, *)
extension DownloadResponse: Response {
    #if !os(watchOS)
    /// The task metrics containing the request / response statistics.
    public var metrics: URLSessionTaskMetrics? { return _metrics as? URLSessionTaskMetrics }
    #endif
}

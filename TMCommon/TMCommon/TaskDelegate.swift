//
//  TaskDelegate.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: TaskDelegate

open class TaskDelegate: NSObject {
    
    // MARK: Properties
    
    open let queue: OperationQueue
    
    var task: URLSessionTask? {
        didSet { reset() }
    }
    var data: Data? { return nil }
    var error: Error?
    var initialResponseTime: CFAbsoluteTime?
    var credential: URLCredential?
    //URLSessionTaskMetrics
    var metrics: AnyObject?
    
    // MARK: Lifecycle
    
    init(task: URLSessionTask?) {
        self.task = task
        self.queue = {
            let operationQueue = OperationQueue()
            operationQueue.maxConcurrentOperationCount = 1
            operationQueue.isSuspended = true
            operationQueue.qualityOfService = .utility
            
            return operationQueue
        }()
    }
    
    func reset() {
        error = nil
        initialResponseTime = nil
    }
    
    // MARK: URLSessionTaskDelegate
    
    var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?
    var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    var taskDidCompleteWithError: ((URLSession, URLSessionTask, Error?) -> Void)?
    
    @objc(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHanlder: @escaping (URLRequest?) -> Void) {
        var redirectionRequest: URLRequest? = request
        if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
            redirectionRequest = taskWillPerformHTTPRedirection(session, task, response, request)
        }
        
        completionHanlder(redirectionRequest)
    }
    
    @objc(URLSession:task:didReceiveChallenge:completionHandler:)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHanlder: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        if let taskDidReceiveChallenge = taskDidReceiveChallenge {
            (disposition, credential) = taskDidReceiveChallenge(session, task, challenge)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            let host = challenge.protectionSpace.host
            if let serverTrustPolicy = session.serverTrustPolicyManager?.serverTrustPolicy(forHost: host), let serverTrust = challenge.protectionSpace.serverTrust {
                if serverTrustPolicy.evalute(serverTrust, forHost: host) {
                    disposition = .useCredential
                    credential = URLCredential(trust: serverTrust)
                } else {
                    disposition = .cancelAuthenticationChallenge
                }
            }
        } else {
            if challenge.previousFailureCount > 0 {
                disposition = .rejectProtectionSpace
            } else {
                credential = self.credential ?? session.configuration.urlCredentialStorage?.defaultCredential(for: challenge.protectionSpace)
                if credential != nil {
                    disposition = .useCredential
                }
            }
        }
        
        completionHanlder(disposition, credential)
    }
    
    @objc(URLSession:task:needNewBodyStream:)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        var bodyStream: InputStream?
        if let taskNeedNewBodyStream = taskNeedNewBodyStream {
            bodyStream = taskNeedNewBodyStream(session, task)
        }
        
        completionHandler(bodyStream)
    }
    
    @objc(URLSession:task:didCompleteWithError:)
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let taskDidCompleteWithError = taskDidCompleteWithError {
            taskDidCompleteWithError(session, task, error)
        } else {
            if let error = error {
                if self.error == nil { self.error = error }
                if let downloadDelegate = self as? DownloadTaskDelegate, let resumeData = (error as NSError).userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                    downloadDelegate.resumeData = resumeData
                }
            }
            
            queue.isSuspended = false
        }
    }
}

// MARK: DataTaskDelegate <- URLSessionDataDelegate

class DataTaskDelegate: TaskDelegate, URLSessionDataDelegate {
    
    // MARK: Properties
    
    override var data: Data? {
        if dataStream != nil {
            return nil
        } else {
            return mutableData
        }
    }
    
    var dataTask: URLSessionDataTask { return task as! URLSessionDataTask }
    var progress: Progress
    var progressHandler: (closure: Request.progressHanlder, queue: DispatchQueue)?
    var dataStream: ((_ data: Data) -> Void)?
    
    private var totalBytesReceived: Int64 = 0
    private var mutableData: Data
    private var expectedContentLength: Int64?
    
    // MARK: Lifecycle
    
    override init(task: URLSessionTask?) {
        mutableData = Data()
        progress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        progress = Progress(totalUnitCount: 0)
        totalBytesReceived = 0
        mutableData = Data()
        expectedContentLength = nil
    }
    
    // MARK: URLSessionDataDelegate
    
    var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionTask, URLSessionDownloadTask) -> Void)?
    var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    var dataTaskWillCacaheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        var disposition: URLSession.ResponseDisposition = .allow
        expectedContentLength = response.expectedContentLength
        if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
            disposition = dataTaskDidReceiveResponse(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didBecome downloadTask: URLSessionDownloadTask) {
        dataTaskDidBecomeDownloadTask?(session, dataTask, downloadTask)
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }
        if let dataTaskDidReceiveData = dataTaskDidReceiveData {
            dataTaskDidReceiveData(session, dataTask, data)
        } else {
            if let dataStream = dataStream {
                dataStream(data)
            } else {
                mutableData.append(data)
            }
            
            let byteReceive = Int64(data.count)
            totalBytesReceived += byteReceive
            let totalByteExpected = dataTask.response?.expectedContentLength ?? NSURLSessionTransferSizeUnknown
            progress.totalUnitCount = totalByteExpected
            progress.completedUnitCount = totalBytesReceived
            if let progressHandler = progressHandler {
                progressHandler.queue.async { progressHandler.closure(self.progress) }
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    willCacheResponse proposedResponse: CachedURLResponse,
                    completionHandler: @escaping (CachedURLResponse?) -> Void) {
        var cachedResponse: CachedURLResponse? = proposedResponse
        if let dataTaskWillCacaheResponse = dataTaskWillCacaheResponse {
            cachedResponse = dataTaskWillCacaheResponse(session, dataTask, proposedResponse)
        }
        
        completionHandler(cachedResponse)
    }
}

// MARK: DownloadTaskDelegate <- URLSessionDownloadDelegate

class DownloadTaskDelegate: TaskDelegate, URLSessionDownloadDelegate {
    
    // MARK: Properties
    
    override var data: Data? { return resumeData }
    
    var downloadTask: URLSessionDownloadTask { return task as! URLSessionDownloadTask }
    var progress: Progress
    var progressHandler: (closure: Request.progressHanlder, queue: DispatchQueue)?
    var resumeData: Data?
    var destination: DownloadRequest.DownloadFileDestination?
    var temporaryURL: URL?
    var destinationURL: URL?
    var fileURL: URL? { return destination != nil ? destinationURL : temporaryURL }
    
    // MARK: Lifecycle
    
    override init(task: URLSessionTask?) {
        progress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        progress = Progress(totalUnitCount: 0)
        resumeData = nil
    }
    
    // MARK: URLSessionDownloadDelegate
    
    var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> URL)?
    var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
    var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        temporaryURL = location
        if let destination = destination {
            let result = destination(location, downloadTask.response as! HTTPURLResponse)
            let destination = result.destinationURL
            let options = result.options
            do {
                destinationURL = destination
                if options.contains(.removePreviousFile) {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                }
                
                if options.contains(.createIntermediateDirectories) {
                    let directory = destination.deletingLastPathComponent()
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                }
                
                try FileManager.default.moveItem(at: location, to: destination)
            } catch {
                self.error = error
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }
        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        } else {
            progress.totalUnitCount = totalBytesExpectedToWrite
            progress.completedUnitCount = totalBytesWritten
            if let progressHandler = progressHandler {
                progressHandler.queue.async { progressHandler.closure(self.progress) }
            }
        }
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
        } else {
            progress.totalUnitCount = expectedTotalBytes
            progress.completedUnitCount = fileOffset
        }
    }
}

// MARK: UploadTaskDelegate

class UploadTaskDelegate: DataTaskDelegate {
    
    // MARK: Properties
    
    var uploadTask: URLSessionUploadTask { return task as! URLSessionUploadTask }
    var uploadProgress: Progress
    var uploadProgressHandler: (closure: Request.progressHanlder, queue: DispatchQueue)?
    
    // MARK: Lifecycle
    
    override init(task: URLSessionTask?) {
        uploadProgress = Progress(totalUnitCount: 0)
        super.init(task: task)
    }
    
    override func reset() {
        super.reset()
        uploadProgress = Progress(totalUnitCount: 0)
    }
    
    // MARK: URLSessionTaskDelegate
    
    var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64,
                    totalbYTESexpectedToSend: Int64) {
        if initialResponseTime == nil { initialResponseTime = CFAbsoluteTimeGetCurrent() }
        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalbYTESexpectedToSend)
        } else {
            uploadProgress.totalUnitCount = totalbYTESexpectedToSend
            uploadProgress.completedUnitCount = totalBytesSent
            if let uploadProgressHandler = uploadProgressHandler {
                uploadProgressHandler.queue.async { uploadProgressHandler.closure(self.uploadProgress) }
            }
        }
    }
    
}


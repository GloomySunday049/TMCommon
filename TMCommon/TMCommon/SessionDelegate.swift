//
//  SessionDelegate.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation


// MARK: SessionDelegate

open class SessionDelegate: NSObject {
    
    // MARK: URLSessionDelegate
    
    open var sessionDidBecomeInvalidWithError: ((URLSession, Error?) -> Void)?
    open var sessionDidReceiveChallenge: ((URLSession, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    open var sessionDidReceiveChallengeWithCompletion: ((URLSession, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    open var sessionDidFinishEventsForBackgroudURLSession: ((URLSession) -> Void)?
    
    // MARK: URLSessionTaskDelegate
    
    open var taskWillPerformHTTPRedirection: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest) -> URLRequest?)?
    open var taskWillPerformHTTPRedirectionWithCompletion: ((URLSession, URLSessionTask, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void)?
    open var taskDidReceiveChallenge: ((URLSession, URLSessionTask, URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?))?
    open var taskDidReceiveChallengeWithCompletion: ((URLSession, URLSessionTask, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?
    open var taskNeedNewBodyStream: ((URLSession, URLSessionTask) -> InputStream?)?
    open var taskNeedNewBodyStreamWithCompletion: ((URLSession, URLSessionTask, (InputStream?) -> Void) -> Void)?
    open var taskDidSendBodyData: ((URLSession, URLSessionTask, Int64, Int64, Int64) -> Void)?
    open var taskDidComplete: ((URLSession, URLSessionTask, Error?) -> Void)?
    
    // MARK: URLSessionDataDelegate
    
    open var dataTaskDidReceiveResponse: ((URLSession, URLSessionDataTask, URLResponse) -> URLSession.ResponseDisposition)?
    open var dataTaskDidReceiveResponseWithCompletion: ((URLSession, URLSessionDataTask, URLResponse, (URLSession.ResponseDisposition) -> Void) -> Void)?
    open var dataTaskDidBecomeDownloadTask: ((URLSession, URLSessionDataTask, URLSessionDownloadTask) -> Void)?
    open var dataTaskDidReceiveData: ((URLSession, URLSessionDataTask, Data) -> Void)?
    open var dataTaskWillCacheResponse: ((URLSession, URLSessionDataTask, CachedURLResponse) -> CachedURLResponse?)?
    open var dataTaskWillCacheResponseWithCompletion: ((URLSession, URLSessionDataTask, CachedURLResponse, (CachedURLResponse?) -> Void) -> Void)?
    
    // MARK: URLSessionDownloadDelegate
    
    open var downloadTaskDidFinishDownloadingToURL: ((URLSession, URLSessionDownloadTask, URL) -> Void)?
    open var downloadTaskDidWriteData: ((URLSession, URLSessionDownloadTask, Int64, Int64, Int64) -> Void)?
    open var downloadTaskDidResumeAtOffset: ((URLSession, URLSessionDownloadTask, Int64, Int64) -> Void)?
    
    //#if !os(watchOS)
    //
    //    // MARK: URLSessionStreamDelegate
    //
    //    open var streamTaskReadClosed: ((URLSession, URLSessionStreamTask) -> Void)?
    //    open var streamTaskWriteClosed: ((URLSession, URLSessionStreamTask) -> Void)?
    //    open var streamTaskBetterRouterDiscovered: ((URLSession, URLSessionStreamTask) -> Void)?
    //    open var streamTaskDidBecomeInputAndOutputStream: ((URLSession, URLSessionStreamTask, InputStream, OutputStream) -> Void)?
    //
    //#endif
    
    var retrier: RequestRetrier?
    weak var sessionManager: SessionManager?
    
    private var requests: [Int : Request] = [:]
    private let lock = NSLock()
    
    open subscript(task: URLSessionTask) -> Request? {
        get {
            lock.lock() ;
            defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }
    
    public override init() {
        super.init()
    }
    
    // MARK: NSObject Override
    
    open override func responds(to aSelector: Selector!) -> Bool {
        #if !os(macOS)
            if aSelector == #selector(URLSessionDelegate.urlSessionDidFinishEvents(forBackgroundURLSession:)) {
                return sessionDidFinishEventsForBackgroudURLSession != nil
            }
        #endif
        
        //        #if !os(watchOS)
        //            switch selector {
        //            case #selector(URLSessionStreamDelegate.urlSession(_:readClosedFor:)):
        //                return streamTaskReadClosed != nil
        //            case #selector(URLSessionStreamDelegate.urlSession(_:writeClosedFor:)):
        //                return streamTaskWriteClosed != nil
        //            case #selector(URLSessionStreamDelegate.urlSession(_:betterRouteDiscoveredFor:)):
        //                return streamTaskBetterRouteDiscovered != nil
        //            case #selector(URLSessionStreamDelegate.urlSession(_:streamTask:didBecome:outputStream:)):
        //                return streamTaskDidBecomeInputAndOutputStreams != nil
        //            default:
        //                break
        //            }
        //        #endif
        
        switch aSelector {
        case #selector(URLSessionDelegate.urlSession(_:didBecomeInvalidWithError:)):
            return sessionDidBecomeInvalidWithError != nil
        case #selector(URLSessionDelegate.urlSession(_:didReceive:completionHandler:)):
            return (sessionDidReceiveChallenge != nil || sessionDidReceiveChallengeWithCompletion != nil)
        case #selector(URLSessionTaskDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)):
            return (taskWillPerformHTTPRedirection != nil || taskWillPerformHTTPRedirectionWithCompletion != nil)
        case #selector(URLSessionDataDelegate.urlSession(_:dataTask:didReceive:completionHandler:)):
            return (dataTaskDidReceiveResponse != nil || dataTaskDidReceiveResponseWithCompletion != nil)
        default:
            return type(of: self).instancesRespond(to: aSelector)
        }
    }
}

// MARK: URLSessionDelegate

extension SessionDelegate: URLSessionDelegate {
    
    open func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        sessionDidBecomeInvalidWithError?(session, error)
    }
    
    open func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard sessionDidReceiveChallengeWithCompletion == nil else {
            sessionDidReceiveChallengeWithCompletion?(session, challenge, completionHandler)
            return
        }
        
        var disposition: URLSession.AuthChallengeDisposition = .performDefaultHandling
        var credential: URLCredential?
        if let sessionDidReceiveChallenge = sessionDidReceiveChallenge {
            (disposition, credential) = sessionDidReceiveChallenge(session, challenge)
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
        }
        
        completionHandler(disposition, credential)
    }
    
    #if !os(macOS)
    open func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    sessionDidFinishEventsForBackgroudURLSession?(session)
    }
    #endif
    
}

// MARK: URLSessionTaskDelegate

extension SessionDelegate: URLSessionTaskDelegate {
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard  taskWillPerformHTTPRedirection == nil else {
            taskWillPerformHTTPRedirectionWithCompletion?(session, task, response, request, completionHandler)
            return
        }
        
        var redirectRequest: URLRequest? = request
        if let taskWillPerformHTTPRedirection = taskWillPerformHTTPRedirection {
            redirectRequest = taskWillPerformHTTPRedirection(session, task, response, request)
        }
        
        completionHandler(redirectRequest)
    }
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard taskDidReceiveChallengeWithCompletion == nil else {
            taskDidReceiveChallengeWithCompletion?(session, task, challenge, completionHandler)
            return
        }
        
        if let taskDidReceiveChallenge = taskDidReceiveChallenge {
            let result = taskDidReceiveChallenge(session, task, challenge)
            completionHandler(result.0, result.1)
        } else if let delegate = self[task]?.delegate {
            delegate.urlSession(session, task: task, didReceive: challenge, completionHanlder: completionHandler)
        } else {
            urlSession(session, didReceive: challenge, completionHandler: completionHandler)
        }
    }
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        guard taskNeedNewBodyStreamWithCompletion == nil else {
            taskNeedNewBodyStreamWithCompletion?(session, task, completionHandler)
            return
        }
        
        if let taskNeedNewBodyStream = taskNeedNewBodyStream {
            completionHandler(taskNeedNewBodyStream(session, task))
        } else if let delegate = self[task]?.delegate {
            delegate.urlSession(session, task: task, needNewBodyStream: completionHandler)
        }
    }
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if let taskDidSendBodyData = taskDidSendBodyData {
            taskDidSendBodyData(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend)
        } else if let delegate = self[task]?.delegate as? UploadTaskDelegate {
            delegate.urlSession(session, task: task, didSendBodyData: bytesSent, totalBytesSent: totalBytesSent, totalbYTESexpectedToSend: totalBytesExpectedToSend)
        }
    }
    
    #if !os(macOS)
    @available(iOS 10.0, *)
    open func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
    self[task]?.delegate.metrics = metrics
    }
    #endif
    
    open func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let completeTask: (URLSession, URLSessionTask, Error?) -> Void = { [weak self] session, task, error in
            guard let strongSelf = self else { return }
            if let taskDidComplete = strongSelf.taskDidComplete {
                taskDidComplete(session, task, error)
            } else if let delegate = strongSelf[task]?.delegate {
                delegate.urlSession(session, task: task, didCompleteWithError: error)
            }
            
            NotificationCenter.default.post(name: NSNotification.Name.Task.DidComplete, object: strongSelf, userInfo: [Notification.Key.Task : task])
            strongSelf[task] = nil
        }
        
        guard let request = self[task], let sessionManager = sessionManager else {
            completeTask(session, task, error)
            return
        }
        
        request.validations.forEach { $0() }
        var error: Error? = error
        if let taskDelegate = self[task]?.delegate, taskDelegate.error != nil {
            error = taskDelegate.error
        }
        
        if let retrier = retrier, let error = error {
            retrier.should(sessionManager, retry: request, with: error) { [weak self] shouldRetry, delay in
                guard shouldRetry else { completeTask(session, task, error); return }
                
                DispatchQueue.utility.after(delay) { [weak self] in
                    guard let strongSelf = self else { return }
                    let retrySucceeded = strongSelf.sessionManager?.retry(request) ?? false
                    if retrySucceeded, let task = request.task {
                        strongSelf[task] = request
                        return
                    } else {
                        completeTask(session, task, error)
                    }
                    
                }
            }
        } else {
            completeTask(session, task, error)
        }
        
    }
}

// MARK: URLSessionDataDelegate

extension SessionDelegate: URLSessionDataDelegate {
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard dataTaskDidReceiveResponseWithCompletion == nil else {
            dataTaskDidReceiveResponseWithCompletion?(session, dataTask, response, completionHandler)
            return
        }
        
        var disposition: URLSession.ResponseDisposition = .allow
        if let dataTaskDidReceiveResponse = dataTaskDidReceiveResponse {
            disposition = dataTaskDidReceiveResponse(session, dataTask, response)
        }
        
        completionHandler(disposition)
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        if let dataTaskDidBecomeDownloadTask = dataTaskDidBecomeDownloadTask {
            dataTaskDidBecomeDownloadTask(session, dataTask, downloadTask)
        } else {
            self[downloadTask]?.delegate = DownloadTaskDelegate(task: dataTask)
        }
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if let dataTaskDidReceiveData = dataTaskDidReceiveData {
            dataTaskDidReceiveData(session, dataTask, data)
        } else if let delegate = self[dataTask]?.delegate as? DataTaskDelegate {
            delegate.urlSession(session, dataTask: dataTask, didReceive: data)
        }
    }
    
    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        guard dataTaskWillCacheResponseWithCompletion == nil else {
            dataTaskWillCacheResponseWithCompletion?(session, dataTask, proposedResponse, completionHandler)
            return
        }
        
        if let dataTaskWillCacheResponse = dataTaskWillCacheResponse {
            completionHandler(dataTaskWillCacheResponse(session, dataTask, proposedResponse))
        } else if let delegate = self[dataTask]?.delegate as? DataTaskDelegate {
            delegate.urlSession(session, dataTask: dataTask, willCacheResponse: proposedResponse, completionHandler: completionHandler)
        } else {
            completionHandler(proposedResponse)
        }
    }
}

// MARK: URLSessionDownloadDelegate

extension SessionDelegate: URLSessionDownloadDelegate {
    
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let downloadTaskDidFinishDownloadingToURL = downloadTaskDidFinishDownloadingToURL {
            downloadTaskDidFinishDownloadingToURL(session, downloadTask, location)
        } else if let delegate = self[downloadTask]?.delegate as? DownloadTaskDelegate {
            delegate.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
        }
    }
    
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let downloadTaskDidWriteData = downloadTaskDidWriteData {
            downloadTaskDidWriteData(session, downloadTask, bytesWritten, totalBytesWritten, totalBytesExpectedToWrite)
        } else if let delgate = self[downloadTask]?.delegate as? DownloadTaskDelegate {
            delgate.urlSession(session, downloadTask: downloadTask, didWriteData: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }
    
    open func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        if let downloadTaskDidResumeAtOffset = downloadTaskDidResumeAtOffset {
            downloadTaskDidResumeAtOffset(session, downloadTask, fileOffset, expectedTotalBytes)
        } else if let delegate = self[downloadTask]?.delegate as? DownloadTaskDelegate {
            delegate.urlSession(session, downloadTask: downloadTask, didResumeAtOffset: fileOffset, expectedTotalBytes: expectedTotalBytes)
        }
    }
}

//#if !os(watchOS)
//
//// MARK: URLSessionStreamDelegate
//
//extension SessionDelegate: URLSessionStreamDelegate {
//
//    open func urlSession(_ session: URLSession, readClosedFor streamTask: URLSessionStreamTask) {
//        streamTaskReadClosed?(session, streamTask)
//    }
//
//    open func urlSession(_ session: URLSession, writeClosedFor streamTask: URLSessionStreamTask) {
//        streamTaskWriteClosed?(session, streamTask)
//    }
//
//    open func urlSession(_ session: URLSession, betterRouteDiscoveredFor streamTask: URLSessionStreamTask) {
//        streamTaskBetterRouterDiscovered?(session, streamTask)
//    }
//
//    open func urlSession(_ session: URLSession, streamTask: URLSessionStreamTask, didBecome inputStream: InputStream, outputStream: OutputStream) {
//        streamTaskDidBecomeInputAndOutputStream?(session, streamTask, inputStream, outputStream)
//    }
//}
//
//#endif

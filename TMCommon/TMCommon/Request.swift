//
//  Request.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: RequestAdapter

public protocol RequestAdapter {
    
    func adapt(_ urlRequest: URLRequest) throws -> URLRequest
}

// MARK: RequstRetrier

public typealias RequestRetryCompletion = (_ shouldRetry: Bool, _ timeDelay: TimeInterval) -> Void

public protocol RequestRetrier {
    
    func should(_ manager: SessionManager, retry requst: Request, with error: Error, completion: @escaping RequestRetryCompletion)
}

// MARK: TaskConvertible

protocol TaskConvertible {
    
    func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask
}

// MARK: Request

public typealias HTTPHeaders = [String : String]

open class Request {
    
    public typealias progressHanlder = (Progress) -> Void
    
    // MARK: RequestTask
    
    enum RequestTask {
        case data(TaskConvertible?, URLSessionTask?)
        case download(TaskConvertible?, URLSessionTask?)
        case upload(TaskConvertible?, URLSessionTask?)
        case stream(TaskConvertible?, URLSessionTask?)
    }
    
    // MARK: Properties
    
    open internal(set) var delegate: TaskDelegate {
        get {
            taskDelegateLock.lock()
            defer { taskDelegateLock.unlock() }
            return taskDelegate
        }
        set {
            taskDelegateLock.lock()
            defer { taskDelegateLock.unlock() }
            taskDelegate = newValue
        }
    }
    open var task: URLSessionTask? { return delegate.task }
    open let session: URLSession
    open var request: URLRequest? { return task?.originalRequest }
    open var response: HTTPURLResponse? { return task?.response as? HTTPURLResponse }
    open internal(set) var retryCount: UInt = 0
    
    let originalTask: TaskConvertible?
    var startTime: CFAbsoluteTime?
    var endTime: CFAbsoluteTime?
    var validations: [() -> Void] = []
    
    private var taskDelegate: TaskDelegate
    private var taskDelegateLock = NSLock()
    
    // MARK: Lifecycle
    
    init(session: URLSession, requestTask: RequestTask, error: Error? = nil) {
        self.session = session
        switch requestTask {
        case .data(let originalTask, let task):
            taskDelegate = DataTaskDelegate(task: task)
            self.originalTask = originalTask
        case .download(let originalTask, let task):
            taskDelegate = DownloadTaskDelegate(task: task)
            self.originalTask = originalTask
        case .upload(let originalTask, let task):
            taskDelegate = UploadTaskDelegate(task: task)
            self.originalTask = originalTask
        case .stream(let originalTask, let task):
            taskDelegate = TaskDelegate(task: task)
            self.originalTask = originalTask
        }
        
        delegate.error = error
        delegate.queue.addOperation { self.endTime = CFAbsoluteTimeGetCurrent() }
    }
    
    // MARK: Authentication
    
    @discardableResult
    open func authenticate(user: String, password: String, persistence: URLCredential.Persistence = .forSession) -> Self {
        let credential = URLCredential(user: user, password: password, persistence: persistence)
        return authenticate(usingCredential: credential)
    }
    
    @discardableResult
    open func authenticate(usingCredential credential: URLCredential) -> Self {
        delegate.credential = credential
        return self
    }
    
    open static func authorizationHeader(user: String, password: String) -> (key: String, value: String)? {
        guard let data = "\(user):\(password)".data(using: .utf8) else { return nil }
        let credential = data.base64EncodedString(options: [])
        return (key: "Authorization", value: "Basic \(credential)")
    }
    
    // MARK: State
    
    open func resume() {
        guard let task = task else { delegate.queue.isSuspended = false; return }
        if startTime == nil { startTime = CFAbsoluteTimeGetCurrent() }
        task.resume()
        NotificationCenter.default.post(name: Notification.Name.Task.DidResume, object: self, userInfo: [Notification.Key.Task : task])
    }
    
    open func suspend() {
        guard let task = task else { return }
        task.suspend()
        NotificationCenter.default.post(name: NSNotification.Name.Task.DidSuspend, object: self, userInfo: [Notification.Key.Task : task])
    }
    
    open func cancel() {
        guard let task = task else { return }
        task.cancel()
        NotificationCenter.default.post(name: NSNotification.Name.Task.DidCancel, object: self, userInfo: [Notification.Key.Task : task])
    }
}

// MARK: CustomStringConvertible

extension Request: CustomStringConvertible {
    
    public var description: String {
        var components: [String] = []
        if let HTTPMethod = request?.httpMethod {
            components.append(HTTPMethod)
        }
        
        if let urlString = request?.url?.absoluteString {
            components.append(urlString)
        }
        
        if let response = response {
            components.append("(\(response.statusCode))")
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: CustomDebugStringConvertible

extension Request: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return cURLRepresentation()
    }
    
    func cURLRepresentation() -> String {
        var components = ["$ curl -i"]
        
        guard let request = self.request,
            let url = request.url,
            let host = url.host
            else {
                return "$ curl command could not be created"
        }
        
        if let httpMethod = request.httpMethod, httpMethod != "GET" {
            components.append("-X \(httpMethod)")
        }
        
        if let credentialStorage = self.session.configuration.urlCredentialStorage {
            let protectionSpace = URLProtectionSpace(
                host: host,
                port: url.port ?? 0,
                protocol: url.scheme,
                realm: host,
                authenticationMethod: NSURLAuthenticationMethodHTTPBasic
            )
            
            if let credentials = credentialStorage.credentials(for: protectionSpace)?.values {
                for credential in credentials {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            } else {
                if let credential = delegate.credential {
                    components.append("-u \(credential.user!):\(credential.password!)")
                }
            }
        }
        
        if session.configuration.httpShouldSetCookies {
            if
                let cookieStorage = session.configuration.httpCookieStorage,
                let cookies = cookieStorage.cookies(for: url), !cookies.isEmpty
            {
                let string = cookies.reduce("") { $0 + "\($1.name)=\($1.value);" }
                components.append("-b \"\(string.substring(to: string.characters.index(before: string.endIndex)))\"")
            }
        }
        
        var headers: [AnyHashable: Any] = [:]
        
        if let additionalHeaders = session.configuration.httpAdditionalHeaders {
            for (field, value) in additionalHeaders where field != AnyHashable("Cookie") {
                headers[field] = value
            }
        }
        
        if let headerFields = request.allHTTPHeaderFields {
            for (field, value) in headerFields where field != "Cookie" {
                headers[field] = value
            }
        }
        
        for (field, value) in headers {
            components.append("-H \"\(field): \(value)\"")
        }
        
        if let httpBodyData = request.httpBody, let httpBody = String(data: httpBodyData, encoding: .utf8) {
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            
            components.append("-d \"\(escapedBody)\"")
        }
        
        components.append("\"\(url.absoluteString)\"")
        
        return components.joined(separator: " \\\n\t")
    }
}

// MARK: DataRequest

open class DataRequest: Request {
    
    // MARK: Requestable <- TaskConvertible
    
    struct Requestable: TaskConvertible {
        
        let urlRequest: URLRequest
        
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            let urlRequest = try self.urlRequest.adapt(using: adapter)
            return queue.syncResult { session.dataTask(with: urlRequest) }
        }
    }
    
    open var progress: Progress { return dataDelegate.progress }
    
    var dataDelegate: DataTaskDelegate { return delegate as! DataTaskDelegate }
    
    // MARK: Stream
    
    @discardableResult
    open func stream(closure: ((Data) -> Void)? = nil) -> Self {
        dataDelegate.dataStream = closure
        return self
    }
    
    // MARK: Porgress
    
    @discardableResult
    open func downloadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping progressHanlder) -> Self {
        dataDelegate.progressHandler = (closure, queue)
        return self
    }
}

// MARK: DownloadRequest

open class DownloadRequest: Request {
    
    // MARK: DownloadOptions
    
    public struct DownloadOptions: OptionSet {
        
        public let rawValue: UInt
        
        public static let createIntermediateDirectories = DownloadOptions(rawValue: 1 << 0)
        public static let removePreviousFile = DownloadOptions(rawValue: 1 << 1)
        
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }
    
    public typealias DownloadFileDestination = (_ temporyURL: URL, _ response: HTTPURLResponse) -> (destinationURL: URL, options: DownloadOptions)
    
    // MARK: Downloadable <- TaskConvertible
    
    enum Downloadable: TaskConvertible {
        case request(URLRequest)
        case resumeData(Data)
        
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            let task: URLSessionTask
            switch self {
            case .request(let request):
                let urlRequest = try request.adapt(using: adapter)
                task = queue.syncResult { session.downloadTask(with: urlRequest) }
            case .resumeData(let resumeData):
                task = queue.syncResult { session.downloadTask(withResumeData: resumeData) }
            }
            
            return task
        }
    }
    
    // MARK: Properties 
    
    open var resumeData: Data? { return downloadDelegate.resumeData }
    open var progress: Progress { return downloadDelegate.progress }
    
    var downloadDelegate: DownloadTaskDelegate { return delegate as! DownloadTaskDelegate }
    
    // MARK: State
    
    open override func cancel() {
        downloadDelegate.downloadTask.cancel { self.downloadDelegate.resumeData = $0 }
        NotificationCenter.default.post(name: NSNotification.Name.Task.DidCancel, object: self, userInfo: [Notification.Key.Task : task])
    }
    
    // MARK: Progress
    
    @discardableResult
    open func downloadProgress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping progressHanlder) -> Self {
        downloadDelegate.progressHandler = (closure, queue)
        return self
    }
    
    // MARK: Desination
    
    open class func suggestedDownloadDestination(for directory: FileManager.SearchPathDirectory = .documentDirectory, in domain: FileManager.SearchPathDomainMask = .userDomainMask) -> DownloadFileDestination {
        return {
            let directoryURLs = FileManager.default.urls(for: directory, in: domain)
            if !directoryURLs.isEmpty {
                return (directoryURLs[0].appendingPathComponent($0.1.suggestedFilename!), [])
            }
            
            return ($0.0, [])
        }
    }
}

// MARK: UploadRequest

open class UploadRequest: DataRequest {
    
    // MARK: Uploadable <- TaskConvertible
    
    enum Uploadable: TaskConvertible {
        case data(Data, URLRequest)
        case file(URL, URLRequest)
        case stream(InputStream, URLRequest)
        
        func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
            let task: URLSessionTask
            switch self {
            case let .data(data, urlRequest):
                let urlRequest = try urlRequest.adapt(using: adapter)
                task = queue.syncResult { session.uploadTask(with: urlRequest, from: data) }
            case let .file(url, urlRrquest):
                let urlRequest = try urlRrquest.adapt(using: adapter)
                task = queue.syncResult { session.uploadTask(with: urlRequest, fromFile: url) }
            case let .stream(_, urlRequest):
                let urlRequest = try urlRequest.adapt(using: adapter)
                task = queue.syncResult { session.uploadTask(withStreamedRequest: urlRequest)}
            }
            
            return task
        }
    }
    
    // MARK: Properties
    
    open var uploadProgress: Progress { return uploadDelegate.uploadProgress }
    
    var uploadDelegate: UploadTaskDelegate { return delegate as! UploadTaskDelegate }
    
    // MARK: Progress
    
    @discardableResult
    open func uploadprogress(queue: DispatchQueue = DispatchQueue.main, closure: @escaping progressHanlder) -> Self {
        uploadDelegate.uploadProgressHandler = (closure, queue)
        return self
    }
}

//#if !os(watchOS)
//
//    /// Specific type of `Request` that manages an underlying `URLSessionStreamTask`.
//    open class StreamRequest: Request {
//        enum Streamable: TaskConvertible {
//            case stream(hostName: String, port: Int)
//            case netService(NetService)
//            
//            func task(session: URLSession, adapter: RequestAdapter?, queue: DispatchQueue) throws -> URLSessionTask {
//                let task: URLSessionTask
//                
//                switch self {
//                case let .stream(hostName, port):
//                    task = queue.syncResult { session.streamTask(withHostName: hostName, port: port) }
//                case let .netService(netService):
//                    task = queue.syncResult { session.streamTask(with: netService) }
//                }
//                
//                return task
//            }
//        }
//    }
//    
//#endif

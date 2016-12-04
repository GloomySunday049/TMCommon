//
//  SessionManager.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: SessionManager

open class SessionManager {
    
    // MARK: MultipartFormDataEncodingResult
    
    public enum MultipartFormDataEncodingResult {
        case success(request: UploadRequest, streamingFromDisk: Bool, streamFileURL: URL?)
        case failure(Error)
    }
    
    // MARK: Properties
    
    open static let `default`: SessionManager = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = SessionManager.defaultHTTPHeaders
        
        return SessionManager(configuration: configuration)
    }()
    open static let defaultHTTPHeaders: HTTPHeaders = {
        // Accept-Encoding HTTP Header; see https://tools.ietf.org/html/rfc7230#section-4.2.3
        let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"
        
        // Accept-Language HTTP Header; see https://tools.ietf.org/html/rfc7231#section-5.3.5
        let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
            let quality = 1.0 - (Double(index) * 0.1)
            return "\(languageCode);q=\(quality)"
            }.joined(separator: ", ")
        
        // User-Agent Header; see https://tools.ietf.org/html/rfc7231#section-5.5.3
        // Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 10.0.0) Alamofire/4.0.0`
        let userAgent: String = {
            if let info = Bundle.main.infoDictionary {
                let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
                let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
                
                let osNameVersion: String = {
                    let version = ProcessInfo.processInfo.operatingSystemVersion
                    let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                    
                    let osName: String = {
                        #if os(iOS)
                            return "iOS"
                        #elseif os(watchOS)
                            return "watchOS"
                        #elseif os(tvOS)
                            return "tvOS"
                        #elseif os(macOS)
                            return "OS X"
                        #elseif os(Linux)
                            return "Linux"
                        #else
                            return "Unknown"
                        #endif
                    }()
                    
                    return "\(osName) \(versionString)"
                }()
                
                let alamofireVersion: String = {
                    guard
                        let afInfo = Bundle(for: SessionManager.self).infoDictionary,
                        let build = afInfo["CFBundleShortVersionString"]
                        else { return "Unknown" }
                    
                    return "Alamofire/\(build)"
                }()
                
                return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) \(alamofireVersion)"
            }
            
            return "Alamofire"
        }()
        
        return [
            "Accept-Encoding": acceptEncoding,
            "Accept-Language": acceptLanguage,
            "User-Agent": userAgent
        ]
    }()
    open static let multipartFormDataEncodingMemoryThreshould: UInt64 = 10_000_000
    
    open let session: URLSession
    open let delegate: SessionDelegate
    
    open var startRequestsImmediately: Bool = true
    open var adapter: RequestAdapter?
    open var retrier: RequestRetrier? {
        get { return delegate.retrier }
        set { delegate.retrier = newValue }
    }
    open var backgroundCompletionHandler: (() -> Void)?
    
    let queue = DispatchQueue(label: "cn.petsknow.session-manager." + UUID().uuidString)
    
    // MARK: Lifecycle
    
    public init(configuration: URLSessionConfiguration = URLSessionConfiguration.default, delegate: SessionDelegate = SessionDelegate(), serverTrustPolicyManager: ServerTrustPolicyManager? = nil) {
        self.delegate = delegate
        self.session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    public init?(session: URLSession, delegate: SessionDelegate, serverTrustPolicyManager: ServerTrustPolicyManager? = nil) {
        guard delegate === session.delegate else { return nil }
        self.delegate = delegate
        self.session = session
        commonInit(serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    private func commonInit(serverTrustPolicyManager: ServerTrustPolicyManager?) {
        session.serverTrustPolicyManager = serverTrustPolicyManager
        delegate.sessionManager = self
        delegate.sessionDidFinishEventsForBackgroudURLSession = { [weak self] session in
            guard let strongSelf = self else { return }
            DispatchQueue.main.async { strongSelf.backgroundCompletionHandler?() }
        }
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    
    // MARK: Data Request
    
    @discardableResult
    open func request(_ url: URLConvertible,
                      method: HTTPMethod = .get,
                      parameters: Parameters? = nil,
                      encoding: ParamterEncoding = URLEncoding.default,
                      headers: HTTPHeaders? = nil) -> DataRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return request(encodedURLRequest)
        } catch {
            return request(failedWith: error)
        }
        
    }
    
    open func request(_ urlRequest: URLRequestConvertible) -> DataRequest {
        do {
            let originalRequest = try urlRequest.asURLRequest()
            let originalTask = DataRequest.Requestable(urlRequest: originalRequest)
            let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
            let request = DataRequest(session: session, requestTask: .data(originalTask, task))
            delegate[task] = request
            if startRequestsImmediately { request.resume() }
            return request
        } catch {
            return request(failedWith: error)
        }
    }
    
    // MARK: Request Implementation
    
    private func request(failedWith error: Error) -> DataRequest {
        let request = DataRequest(session: session, requestTask: .data(nil, nil), error: error)
        if startRequestsImmediately { request.resume() }
        return request
    }
    
    // MARK: Download Request
    
    @discardableResult
    open func download(_ url: URLConvertible,
                       method: HTTPMethod = .get,
                       parameters: Parameters? = nil,
                       encoding: ParamterEncoding = URLEncoding.default,
                       headers: HTTPHeaders? = nil,
                       to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return download(encodedURLRequest, to: destination)
        } catch {
            return download(failedWith: error)
        }
    }
    
    @discardableResult
    open func download(_ urlRequest: URLRequestConvertible,
                       to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return download(.request(urlRequest), to: destination)
        } catch {
            return download(failedWith: error)
        }
    }
    
    // MARK: Download - Resume Data
    
    @discardableResult
    open func download(resumingWith resumeData: Data,
                       to destination: DownloadRequest.DownloadFileDestination? = nil) -> DownloadRequest {
        return download(.resumeData(resumeData), to: destination)
    }
    
    private func download(_ downloadable: DownloadRequest.Downloadable,
                          to destination: DownloadRequest.DownloadFileDestination?) -> DownloadRequest {
        do {
            let task = try downloadable.task(session: session, adapter: adapter, queue: queue)
            let request = DownloadRequest(session: session, requestTask: .download(downloadable, task))
            request.downloadDelegate.destination = destination
            delegate[task] = request
            if startRequestsImmediately { request.resume() }
            return request
        } catch {
            return download(failedWith: error)
        }
    }
    
    private func download(failedWith error: Error) -> DownloadRequest {
        let download = DownloadRequest(session: session, requestTask: .download(nil, nil), error: error)
        if startRequestsImmediately { download.resume() }
        return download
    }
    
    // MARK: Upload Request
    
    @discardableResult
    open func upload(_ fileURL: URL,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(fileURL, with: urlRequest)
        } catch {
            return upload(failedWith: error)
        }
    }
    
    @discardableResult
    open func upload(_ fileURL:URL,
                     with urlRequest: URLRequestConvertible) -> UploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.file(fileURL, urlRequest))
        } catch {
            return upload(failedWith: error)
        }
    }
    
    @discardableResult
    open func upload(_ data: Data,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(data, with: urlRequest)
        } catch {
            return upload(failedWith: error)
        }
    }
    
    @discardableResult
    open func upload(_ data: Data,
                     with urlRequest: URLRequestConvertible) -> UploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.data(data, urlRequest))
        } catch {
            return upload(failedWith: error)
        }
    }
    
    @discardableResult
    open func upload(_ stream: InputStream,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil) -> UploadRequest {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(stream, with: urlRequest)
        } catch {
            return upload(failedWith: error)
        }
    }
    
    @discardableResult
    open func upload(_ stream: InputStream,
                     with urlRequest: URLRequestConvertible) -> UploadRequest {
        do {
            let urlRequest = try urlRequest.asURLRequest()
            return upload(.stream(stream, urlRequest))
        } catch {
            return upload(failedWith: error)
        }
    }
    
    // MARK: Upload - MultipartFormData
    
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshold encodingMemoryThreshold: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshould,
                     to url: URLConvertible,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?) {
        do {
            let urlRequest = try URLRequest(url: url, method: method, headers: headers)
            return upload(multipartFormData: multipartFormData, usingThreshould: encodingMemoryThreshold, with: urlRequest, encodingCompletion: encodingCompletion)
        } catch {
            DispatchQueue.main.async { encodingCompletion?(.failure(error)) }
        }
    }
    
    open func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     usingThreshould encodingMemoryThreshould: UInt64 = SessionManager.multipartFormDataEncodingMemoryThreshould,
                     with urlRequest: URLRequestConvertible,
                     encodingCompletion: ((MultipartFormDataEncodingResult) -> Void)?) {
        DispatchQueue.global(qos: .utility).async {
            let formData = MultipartFormData()
            multipartFormData(formData)
            do {
                var urlRequestWithContentType = try urlRequest.asURLRequest()
                urlRequestWithContentType.setValue(formData.contentType, forHTTPHeaderField: "Content-Type")
                let isBackgroundSession = self.session.configuration.identifier != nil
                if formData.contentLength < encodingMemoryThreshould && !isBackgroundSession {
                    let data = try formData.encode()
                    let encodingResult = MultipartFormDataEncodingResult.success(request: self.upload(data, with: urlRequestWithContentType), streamingFromDisk: false, streamFileURL: nil)
                    DispatchQueue.main.async { encodingCompletion?(encodingResult) }
                } else {
                    let fileManager = FileManager.default
                    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    let directoryURL = tempDirectoryURL.appendingPathComponent("cn.petsknow.manager/multipart.form.data")
                    let fileName = UUID().uuidString
                    let fileURL = directoryURL.appendingPathComponent(fileName)
                    var directoryError: Error?
                    self.queue.sync {
                        do {
                            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                        } catch {
                            directoryError = error
                        }
                    }
                    
                    if let directoryError = directoryError { throw directoryError }
                    try formData.writeEncodedData(to: fileURL)
                    DispatchQueue.main.async {
                        let encodingResult = MultipartFormDataEncodingResult.success(request: self.upload(fileURL, with: urlRequestWithContentType), streamingFromDisk: true, streamFileURL: fileURL)
                        encodingCompletion?(encodingResult)
                    }
                }
            } catch {
                DispatchQueue.main.async { encodingCompletion?(.failure(error)) }
            }
        }
    }
    
    // MARK: Private - Upload Implementation
    
    private func upload(_ uploadable: UploadRequest.Uploadable) -> UploadRequest {
        do {
            let task = try uploadable.task(session: session, adapter: adapter, queue: queue)
            let upload = UploadRequest(session: session, requestTask: .upload(uploadable, task))
            if case let .stream(inputStream, _) = uploadable {
                upload.delegate.taskNeedNewBodyStream = { _, _ in inputStream }
            }
            
            delegate[task] = upload
            if startRequestsImmediately { upload.resume() }
            
            return upload
        } catch {
            return upload(failedWith: error)
        }
    }
    
    private func upload(failedWith error: Error) -> UploadRequest {
        let upload = UploadRequest(session: session, requestTask: .upload(nil, nil), error: error)
        if startRequestsImmediately { upload.resume() }
        
        return upload
    }
    
//#if !os(watchOS)
//    
//    // MARK: - Stream Request
//    
//    @discardableResult
//    open func stream(withHostName hostName: String, port: Int) -> StreamRequest {
//        return stream(.stream(hostName: hostName, port: port))
//    }
//    
//    @discardableResult
//    open func stream(with netService: NetService) -> StreamRequest {
//        return stream(.netService(netService))
//    }
//    
//    // MARK: Private - Stream Implementation
//    
//    private func stream(_ streamable: StreamRequest.Streamable) -> StreamRequest {
//        do {
//            let task = try streamable.task(session: session, adapter: adapter, queue: queue)
//            let request = StreamRequest(session: session, requestTask: .stream(streamable, task))
//            
//            delegate[task] = request
//            
//            if startRequestsImmediately { request.resume() }
//            
//            return request
//        } catch {
//            return stream(failedWith: error)
//        }
//    }
//    
//    private func stream(failedWith error: Error) -> StreamRequest {
//        let stream = StreamRequest(session: session, requestTask: .stream(nil, nil), error: error)
//        if startRequestsImmediately { stream.resume() }
//        return stream
//    }
//    
//#endif
    
    
    // MARK: Internal - Retry Request
    
    func retry(_ request: Request) -> Bool {
        guard let originalTask = request.originalTask else { return false }
        do {
            let task = try originalTask.task(session: session, adapter: adapter, queue: queue)
            request.delegate.task = task
            request.retryCount += 1
            request.startTime = CFAbsoluteTimeGetCurrent()
            request.endTime = nil
            request.resume()
            return true
        } catch {
            request.delegate.error = error
            return false
        }
    }
}

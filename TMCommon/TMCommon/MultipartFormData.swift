//
//  MultipartFormData.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation
import MobileCoreServices

// MARK: MultipartFormData

open class MultipartFormData {
    
    // MARK: EncodingCharacters
    
    struct EncodingCharacters {
        static let crlf = "\r\n"
    }
    
    // MARK: BoundaryGenerator
    
    struct BoundaryGenerator {
        
        enum BoundaryType {
            case initial, encapsulated, final
        }
        
        static func randomBoundary() -> String {
            return String(format: "cn.petsknow.boundary.%08x%08x", arc4random(), arc4random())
        }
        
        static func boundaryData(forBoundaryType boundaryType: BoundaryType, boundary: String) -> Data {
            let boundaryText: String
            switch boundaryType {
            case .initial:
                boundaryText = "--\(boundary)\(EncodingCharacters.crlf)"
            case .encapsulated:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)\(EncodingCharacters.crlf)"
            case .final:
                boundaryText = "\(EncodingCharacters.crlf)--\(boundary)--\(EncodingCharacters.crlf)"
            }
            
            return boundaryText.data(using: .utf8, allowLossyConversion: false)!
            
        }
    }
    
    // MARK: BodyPart
    
    class BodyPart {
        
        let headers: HTTPHeaders
        let bodyStream: InputStream
        let bodyContentLength: UInt64
        var hasInitialBoundary = false
        var hasFinalBounday = false
        
        init(headers: HTTPHeaders, bodyStream: InputStream, bodyContentLength: UInt64) {
            self.headers = headers
            self.bodyStream = bodyStream
            self.bodyContentLength = bodyContentLength
        }
    }
    
    // MARK: Properties
    
    open var contentType: String { return "multipart/form-data; bounday=\(boundary)" }
    
    public var contentLength: UInt64 { return bodyParts.reduce(0) { $0 + $1.bodyContentLength} }
    public let boundary: String
    
    private var bodyParts: [BodyPart]
    private var bodyPartError: NTError?
    private let streamBufferSize: Int
    
    public init() {
        self.boundary = BoundaryGenerator.randomBoundary()
        self.bodyParts = []
        self.streamBufferSize = 1024
    }
    
    // MARK: Body Parts
    
    public func append(_ data: Data, withName name: String) {
        let headers = contentHeaders(withName: name)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, mimeType: String) {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ data: Data, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, mimeType: mimeType)
        let stream = InputStream(data: data)
        let length = UInt64(data.count)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ fileURL: URL, withName name: String) {
        let fileName = fileURL.lastPathComponent
        let pathExtension = fileURL.pathExtension
        if !fileName.isEmpty && !pathExtension.isEmpty {
            let mime = mimeType(forPathExtension: pathExtension)
            append(fileURL, withName: name, fileName: fileName, mimeType: mime)
        } else {
            setBodyPartError(withReason: .bodyPartFilenameInvalid(in: fileURL))
        }
    }
    
    public func append(_ fileURL: URL, withName name: String, fileName: String, mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        guard  fileURL.isFileURL else {
            setBodyPartError(withReason: .bodyPartURLInvalid(url: fileURL))
            return
        }
        
        do {
            let isReachable = try fileURL.checkResourceIsReachable()
            guard  isReachable else {
                setBodyPartError(withReason: .bodyPartFileNotReachable(at: fileURL))
                return
            }
        } catch {
            setBodyPartError(withReason: .bodyPartFileNotReachableWithError(at: fileURL, error: error))
            return
        }
        
        var isDirectory: ObjCBool = false
        let path = fileURL.path
        guard  FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && !isDirectory.boolValue else {
            setBodyPartError(withReason: .bodyPartFileIsDirectory(at: fileURL))
            return
        }
        
        let bodyContentLength: UInt64
        do {
            guard let fileSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber else {
                setBodyPartError(withReason: .bodyPartFileSizeNotAvailable(at: fileURL))
                return
            }
            
            bodyContentLength = fileSize.uint64Value
        } catch {
            setBodyPartError(withReason: .bodyPartFileSizeQueryFailedWithError(forURL: fileURL, error: error))
            return
        }
        
        guard let stream = InputStream(url: fileURL) else {
            setBodyPartError(withReason: .bodyPartInputStreamCreationFailed(for: fileURL))
            return
        }
        
        append(stream, withLength: bodyContentLength, headers: headers)
    }
    
    public func append(_ stream: InputStream,
                       withLength length: UInt64,
                       name: String,
                       fileName: String,
                       mimeType: String) {
        let headers = contentHeaders(withName: name, fileName: fileName, mimeType: mimeType)
        append(stream, withLength: length, headers: headers)
    }
    
    public func append(_ stream: InputStream, withLength length: UInt64, headers: HTTPHeaders) {
        let bodyPart = BodyPart(headers: headers, bodyStream: stream, bodyContentLength: length)
        bodyParts.append(bodyPart)
    }
    
    // MARK: Data Encoding
    
    public func encode() throws -> Data {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        var encoded = Data()
        bodyParts.first?.hasInitialBoundary = true
        bodyParts.last?.hasFinalBounday = true
        for bodyPart in bodyParts {
            let encodedData = try encode(bodyPart)
            encoded.append(encodedData)
        }
        
        return encoded
    }
    
    public func writeEncodedData(to fileURL: URL) throws {
        if let bodyPartError = bodyPartError {
            throw bodyPartError
        }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            throw NTError.multipartEncodingFailed(reason: .outputStreamFileAlreadyExists(at: fileURL))
        } else if !fileURL.isFileURL {
            throw NTError.multipartEncodingFailed(reason: .outputStreamURLInvalid(url: fileURL))
        }
        
        guard let outputStream = OutputStream(url: fileURL, append: false) else {
            throw NTError.multipartEncodingFailed(reason: .outputStreamCreationFailed(for: fileURL))
        }
        
        outputStream.open()
        defer { outputStream.close() }
        self.bodyParts.first?.hasInitialBoundary = true
        self.bodyParts.last?.hasFinalBounday = true
        for bodyPart in bodyParts {
            try write(bodyPart, to: outputStream)
        }
    }
    
    // MARK: Private - Body Part Encoding
    
    private func encode(_ bodyPart: BodyPart) throws -> Data {
        var encoded = Data()
        let initialData = bodyPart.hasInitialBoundary ? initialBoudnaryData() : encapsulatedBoundaryData()
        encoded.append(initialData)
        let headerData = encodeHeaders(for: bodyPart)
        encoded.append(headerData)
        let bodyStreamData = try encodeBodyStream(for: bodyPart)
        encoded.append(bodyStreamData)
        if bodyPart.hasFinalBounday {
            encoded.append(contentsOf: finalBoundaryData())
        }
        
        return encoded
    }
    
    private func encodeHeaders(for bodyPart: BodyPart) -> Data {
        var headerText = ""
        for (key, value) in bodyPart.headers {
            headerText += "\(key): \(value)\(EncodingCharacters.crlf)"
        }
        
        headerText += EncodingCharacters.crlf
        return headerText.data(using: .utf8, allowLossyConversion: false)!
    }
    
    private func encodeBodyStream(for bodyPart: BodyPart) throws -> Data {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }
        var encoded = Data()
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            if let error = inputStream.streamError {
                throw NTError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: error))
            }
            
            if bytesRead > 0 {
                encoded.append(buffer, count: bytesRead)
            } else {
                break
            }
        }
        
        return encoded
    }
    
    // MARK: Private - Writing Body Part To Output Stream
    
    private func write(_ bodyPart: BodyPart, to outputStream: OutputStream) throws {
        try writeInitialBoundaryData(for: bodyPart, to: outputStream)
        try writeHeadersData(for: bodyPart, to: outputStream)
        try writeBodyStream(for: bodyPart, to: outputStream)
        try writeFinalBoundaryData(for: bodyPart, to: outputStream)
    }
    
    private func writeInitialBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let initialData = bodyPart.hasInitialBoundary ? initialBoudnaryData() : encapsulatedBoundaryData()
        return try write(initialData, to: outputStream)
    }
    
    private func writeHeadersData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let headerData = encodeHeaders(for: bodyPart)
        return try write(headerData, to: outputStream)
    }
    
    private func writeBodyStream(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        let inputStream = bodyPart.bodyStream
        inputStream.open()
        defer { inputStream.close() }
        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](repeating: 0, count: streamBufferSize)
            let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
            if let streamError = inputStream.streamError {
                throw NTError.multipartEncodingFailed(reason: .inputStreamReadFailed(error: streamError))
            }
            
            if bytesRead > 0 {
                if buffer.count != bytesRead {
                    buffer = Array(buffer[0..<bytesRead])
                }
                
                try write(&buffer, to: outputStream)
            } else {
                break
            }
        }
    }
    
    private func writeFinalBoundaryData(for bodyPart: BodyPart, to outputStream: OutputStream) throws {
        if bodyPart.hasFinalBounday {
            return try write(finalBoundaryData(), to: outputStream)
        }
    }
    
    // MARK: Private - Writing Byffered Data To Output Stream
    
    private func write(_ data: Data, to outputStream: OutputStream) throws {
        var buffer = [UInt8](repeating: 0, count: data.count)
        data.copyBytes(to: &buffer, count: data.count)
        return try write(&buffer, to: outputStream)
    }
    
    private func write(_ buffer: inout [UInt8], to outputStream: OutputStream) throws {
        var bytesToWrite = buffer.count
        while bytesToWrite > 0, outputStream.hasSpaceAvailable {
            let bytesWritten = outputStream.write(buffer, maxLength: bytesToWrite)
            if let error = outputStream.streamError {
                throw NTError.multipartEncodingFailed(reason: .outputStreamWriteFailed(error: error))
            }
            
            bytesToWrite -= bytesWritten
            if bytesToWrite > 0 {
                buffer = Array(buffer[bytesWritten..<buffer.count])
            }
        }
    }
    
    // MARK: Private - Mime Type
    
    private func mimeType(forPathExtension pathExtension: String) -> String {
        if let id = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension as CFString, nil)?.takeRetainedValue(), let contentType = UTTypeCopyPreferredTagWithClass(id, kUTTagClassMIMEType)?.takeRetainedValue() {
            return contentType as String
        }
        
        return "application/octet-stream"
    }
    
    // MARK: Private - Content Headers
    
    private func contentHeaders(withName name: String, fileName: String? = nil, mimeType: String? = nil) -> [String : String] {
        var disposition = "form-data; name=\"\(name)\""
        if let fileName = fileName { disposition += "; filename=\"\(fileName)\"" }
        var headers = ["Content-Disposition" : disposition]
        if let mimeType = mimeType { headers["Content-Type"] = mimeType }
        
        return headers
    }
    
    // MARK: Private - Boundary Encoding
    
    private func initialBoudnaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .initial, boundary: boundary)
    }
    
    private func encapsulatedBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .encapsulated, boundary: boundary)
    }
    
    private func finalBoundaryData() -> Data {
        return BoundaryGenerator.boundaryData(forBoundaryType: .final, boundary: boundary)
    }
    
    // MARK: Private - Errors 
    
    private func setBodyPartError(withReason reason: NTError.MultipartEncodingFailureReason) {
        guard bodyPartError == nil else { return }
        bodyPartError = NTError.multipartEncodingFailed(reason: reason)
    }
    
    
        
}

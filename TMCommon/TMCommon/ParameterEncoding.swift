//
//  ParameterEncoding.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: HTTPMethod

public enum HTTPMethod: String {
    
    case options = "OPTIONS"
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case tract = "TRACT"
    case connect = "CONNECT"
}

public typealias Parameters = [String : Any]

// MARK: ParamterEncoding

public protocol ParamterEncoding {
    
    func encode(_ urlRequest: URLRequestConvertible, with paramters: Parameters?) throws -> URLRequest
}

// MARK: URLEncoding

public struct URLEncoding: ParamterEncoding {
    
    public enum Destination {
        case methodDependent, queryString, httpBody
    }
    
    public static var `default`: URLEncoding { return URLEncoding() }
    public static var methodDenpendent: URLEncoding { return URLEncoding() }
    public static var queryString: URLEncoding { return URLEncoding() }
    public static var httpBody: URLEncoding { return URLEncoding() }
    public let destination: Destination
    
    public init(destination: Destination = .methodDependent) {
        self.destination = destination
    }
    
    // MARK: Encoding
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else {
            return urlRequest
        }
        
        if let method = HTTPMethod(rawValue: urlRequest.httpMethod ?? "GET"), encodesParametersInURL(with: method) {
            guard let url = urlRequest.url else {
                throw NTError.parameterEncodingFailed(reason: .missingURL)
            }
            
            if var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false), !parameters.isEmpty {
                let percentEncodeQuery = (urlComponents.percentEncodedQuery.map { $0 + "&"} ?? "") + query(parameters)
                urlComponents.percentEncodedQuery = percentEncodeQuery
                urlRequest.url = urlComponents.url
            }
        } else {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
            
            urlRequest.httpBody = query(parameters).data(using: .utf8, allowLossyConversion: false)
        }
        
        return urlRequest
    }
    
    public func queryComponents(fromKey key: String, value: Any) ->[(String, String)] {
        var components: [(String, String)] = []
        if let dictionary = value as? [String : Any] {
            for (nestedKey, value) in dictionary {
                components += queryComponents(fromKey: "\(key)[\(nestedKey)]", value: value)
            }
        } else if let array = value as? [Any] {
            for value in array  {
                components += queryComponents(fromKey: "\(key)[]", value: value)
            }
        } else if let value = value as? NSNumber {
            if value.isBool {
                components.append((escape(key), escape((value.boolValue ? "1" : "0"))))
            } else {
                components.append((escape(key), escape("\(value)")))
            }
        } else if let bool = value as? Bool {
            components.append((escape(key), escape(bool ? "1" : "0")))
        } else {
            components.append((escape(key), escape("\(value)")))
        }
        
        return components
    }
    
    public func escape(_ string: String) -> String {
        let generalDelimitersToEncode = ":#[]@"
        let subDelimitersToEncode = "!$&'()*+,;="
        var allowCharacterSet = CharacterSet.urlQueryAllowed
        allowCharacterSet.remove(charactersIn: "\(generalDelimitersToEncode)\(subDelimitersToEncode)")
        
        return string.addingPercentEncoding(withAllowedCharacters: allowCharacterSet) ?? string
    }
    
    private func query(_ paramters: [String : Any]) -> String {
        var components: [(String, String)] = []
        for key in paramters.keys.sorted(by: <) {
            let value = paramters[key]!
            components += queryComponents(fromKey: key, value: value)
        }
        
        return components.map { "\($0)=\($1)" }.joined(separator: "&")
    }
    
    private func encodesParametersInURL(with Method: HTTPMethod) -> Bool {
        switch destination {
        case .queryString:
            return true
        case .httpBody:
            return false
        default:
            break
        }
        
        switch Method {
        case .get, .head, .delete:
            return true
        default:
            return false
        }
    }
}

// MARK: JSONEncoding

public struct JSONEncoding: ParamterEncoding {
    
    public static var `default`: JSONEncoding { return JSONEncoding() }
    public static var prettyPrinted: JSONEncoding { return JSONEncoding(prettify: true) }
    public let prettify: Bool
    
    public init(prettify: Bool = false) {
        self.prettify = prettify
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else { return urlRequest }
        
        //: TODO other way
        
        if let data = JSONSerializer.serializeToJSON(object: parameters, prettify: prettify)?.data(using: .utf8) {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            
            urlRequest.httpBody = data
        } else {
            throw NTError.parameterEncodingFailed(reason: .jsonEncodingFailed(error: NSError()))
        }
        
        return urlRequest
    }
}

public struct PropertyListEncoding: ParamterEncoding {
    
    public static var `default`: PropertyListEncoding { return PropertyListEncoding() }
    public static var xml: PropertyListEncoding { return PropertyListEncoding(format: .xml) }
    public static var binary: PropertyListEncoding { return PropertyListEncoding(format: .binary) }
    public let format: PropertyListSerialization.PropertyListFormat
    public let options: PropertyListSerialization.WriteOptions
    
    public init(format: PropertyListSerialization.PropertyListFormat = .xml, options: PropertyListSerialization.WriteOptions = 0) {
        self.format = format
        self.options = options
    }
    
    public func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()
        guard let parameters = parameters else { return urlRequest }
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: parameters, format: format, options: options)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/x-plist", forHTTPHeaderField: "Content-Type")
            }
            
            urlRequest.httpBody = data
        } catch {
            throw NTError.parameterEncodingFailed(reason: .propertyListEncodingFailed(error: error))
        }
        
        return urlRequest
    }
}

// MARK: NSNumber Extension

extension NSNumber {
    
    fileprivate var isBool: Bool { return CFBooleanGetTypeID() == CFGetTypeID(self) }
}

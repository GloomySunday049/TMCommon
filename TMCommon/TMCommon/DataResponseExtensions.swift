//
//  DataResponseExtensions.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/6.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation
import Alamofire
import HandyJSON

extension Request {
    
    public static func serializeResponseModel<T : HandyJSON>(options: JSONSerialization.ReadingOptions, response: HTTPURLResponse?, data: Data?, error: Error?) -> Result<T?> {
        guard error == nil else {
            return .failure(error!)
        }
        
        if let response = response, [204,205].contains(response.statusCode) {
            return .success(nil)
        }
        
        guard let validData = data, validData.count > 0 else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
        
        if let jsonString = String(data: validData, encoding: String.Encoding.utf8) {
            return .success(JSONDeserializer<T>.deserializeFrom(json: jsonString))
        } else {
            return .failure(AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength))
        }
    }
}

extension DataRequest {
    
    public static func jsonModelResponseSerializer<T: HandyJSON>(options: JSONSerialization.ReadingOptions = .allowFragments) -> DataResponseSerializer<T?> {
        return DataResponseSerializer {
            return Request.serializeResponseModel(options: options, response: $0.1, data: $0.2, error: $0.3)
        }
    }
    
    @discardableResult
    public func responseModel<T: HandyJSON>(queue: DispatchQueue? = nil,
                              options: JSONSerialization.ReadingOptions = .allowFragments,
                              completionHandler: @escaping (DataResponse<T?>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: DataRequest.jsonModelResponseSerializer(options: options), completionHandler: completionHandler)
    }
}

//
//  APIUtil.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/5.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation
import HandyJSON
import Alamofire

public class APIUtil<T: HandyJSON> {
    
    public static func loadAPI(url: String, method: HTTPMethod, parameter: Parameters?, headers: HTTPHeaders?, completionHandler: @escaping (T?) -> Void) {
        switch method {
        case .get:
            request(url, method: method, parameters: parameter, encoding: URLEncoding.default, headers: headers).responseModel(completionHandler: { (rs: DataResponse<T?>) in
                if rs.result.isSuccess {
                    if let vlaue = rs.result.value {
                        completionHandler(vlaue)
                    } else {
                        completionHandler(nil)
                    }
                } else {
                    completionHandler(nil)
                }
            })
        case .post:
            request(url, method: method, parameters: parameter, encoding: JSONEncoding.default, headers: headers).responseModel(completionHandler: { (rs: DataResponse<T?>) in
                if rs.result.isSuccess {
                    if let vlaue = rs.result.value {
                        completionHandler(vlaue)
                    } else {
                        completionHandler(nil)
                    }
                } else {
                    completionHandler(nil)
                }
            })
        default:
            fatalError("API can not without get/post")
        }
    }
}

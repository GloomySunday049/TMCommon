//
//  APIUtil.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/5.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

public class APIUtil<T: TMJSON> {
    
    public static func loadAPI(uri: String, method: HTTPMethod, parameter: Parameters?, headers: HTTPHeaders?, completionHandler: @escaping (T?) -> Void) {
        switch method {
        case .get:
            _data(uri, method: method, parameters: parameter, encoding: URLEncoding.default, headers: headers).responseModel(completionHandler: { (rs: DataResponse<T?>?) in
                print(rs?.result.isSuccess)
                if rs?.result.isSuccess ?? false {
                    if let vlaue = rs?.result.value {
                        completionHandler(vlaue)
                    } else {
                        completionHandler(nil)
                    }
                } else {
                    completionHandler(nil)
                }
            })
        case .post:
            _data(uri, method: method, parameters: parameter, encoding: JSONEncoding.default, headers: headers).responseModel(completionHandler: { (rs: DataResponse<T?>?) in
                print(rs?.result.isSuccess)
                if rs?.result.isSuccess ?? false {
                    if let vlaue = rs?.result.value {
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

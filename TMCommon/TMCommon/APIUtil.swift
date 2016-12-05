//
//  APIUtil.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/5.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

let baseURL = "http://60.205.108.157/ywt_api/"

public class APIUtil<T: TMJSON> {
    
    public static func loadAPI(uri: String, method: HTTPMethod, parameter: Parameters?, completionHandler: @escaping (T?) -> Void) {
        switch method {
        case .get:
            break
        case .post:
            _data(("http://60.205.108.157/ywt_api/" + uri), method: method, parameters: parameter, encoding: JSONEncoding.default, headers: APIUtil.customHeader()).responseModel(completionHandler: { (rs: DataResponse<T?>?) in
                print(rs?.result.isSuccess)
                
                print(rs?.result.value)
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
    
    private static func customHeader() -> HTTPHeaders {
        return ["phone" : "18518167049", "token" : "73e10132b3b035f1bb910c61f2d9ba05"]
    }
}


public class UserModel: TMJSON {
    var expireTime: Double = 0.0
    var id: Int = 0
    var phone: String = ""
    var token: String = ""
    
    
    required public init() {
        
    }
}

//
//  JSONDeserializer.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

public class JSONDeserializer<T : TMJSON> {
    
    public static func deserializeFrom(dic: NSDictionary) -> T? {
        return T.tm_transform(dic: dic, toType: T.self) as? T
    }
    
    public static func deserializeFrom(dic: NSDictionary, designatedPath: String?) -> T? {
        var tempDic: AnyObject? = dic
        if let paths = designatedPath?.components(separatedBy: "."), paths.count > 0 {
            paths.forEach {
                tempDic = (tempDic as? NSDictionary)?.object(forKey: $0) as AnyObject?
            }
        }
        
        
        if let innerDic = tempDic as? NSDictionary {
            return deserializeFrom(dic: innerDic)
        }
        
        return nil
    }
    
    public static func deserializeFrom(json: String) -> T? {
        return deserializeFrom(json: json, designatedPath: nil)
    }
    
    public static func deserializeFrom(json: String?) -> T? {
        if let jsonStr = json {
            return deserializeFrom(json: jsonStr)
        } else {
            return nil
        }
    }
    
    public static func deserializeFrom(json: String, designatedPath: String?) -> T? {
        if let dic = try? JSONSerialization.jsonObject(with: json.data(using: String.Encoding.utf8)!, options: .allowFragments) {
            if let jsonDic = dic as? NSDictionary {
                return deserializeFrom(dic: jsonDic, designatedPath: designatedPath)
            }
        }
        
        return nil
    }
}

//
//  APIRet.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/5.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

public class APIRet<T: TMJSON>: TMJSON {
    var status: Int = 0
    var data: [T] = []
    var msg: String = ""
    var time: Double = 0.0
    
    required public init() {}
}

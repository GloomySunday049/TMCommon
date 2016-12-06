//
//  APIRet.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/12/5.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation
import HandyJSON

public protocol APIRetProtocol: HandyJSON {
    
    associatedtype T
    
    var status: Int { get set}
    var data: [T] { get set}
    var msg: String { get set}
    var time: Double { get set}
}

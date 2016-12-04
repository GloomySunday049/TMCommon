//
//  StringExtensions.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/19.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension String {
    init(count: Int, repeatedString: String) {
        var value = ""
        for _ in 0..<count { value += repeatedString }
        self = value
    }
}

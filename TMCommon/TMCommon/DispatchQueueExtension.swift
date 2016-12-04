//
//  DispatchQueueExtension.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/15.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension DispatchQueue {
    
    static var userInteractive: DispatchQueue {
        return DispatchQueue.global(qos: .userInteractive)
    }
    static var userInitialted: DispatchQueue {
        return DispatchQueue.global(qos: .userInitiated)
    }
    static var utility: DispatchQueue {
        return DispatchQueue.global(qos: .utility)
    }
    static var backgroud: DispatchQueue {
        return DispatchQueue.global(qos: .background)
    }
    
    public func after(_ delay: TimeInterval, execute closure: @escaping () -> Void) {
        asyncAfter(deadline: .now(), execute: closure)
    }
    
    public func syncResult<T>(_ closure: () -> T) -> T {
        var result: T!
        sync { result = closure() }
        return result
    }
}

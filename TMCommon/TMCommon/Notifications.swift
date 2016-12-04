//
//  Notifications.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension Notification.Name {
    
    public struct Task {
        
        public static let DidResume = Notification.Name(rawValue: "cn.petsknow.tm.notification.name.task.didResume")
        public static let DidSuspend = Notification.Name(rawValue: "cn.petsknow.tm.notification.name.task.didSuspend")
        public static let DidCancel = Notification.Name(rawValue: "cn.petsknow.tm.notification.name.task.didCancel")
        public static let DidComplete = Notification.Name(rawValue: "cn.petsknow.tm.notification.name.task.didComplete")
    }
}

extension Notification {
    
    public struct Key {
        
        public static let Task = "cn.petsknow.notification.key.task"
    }
}

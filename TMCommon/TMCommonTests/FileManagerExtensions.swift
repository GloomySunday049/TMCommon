//
//  FileManagerExtensions.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/19.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension FileManager {
    
    static var temporaryDirectoryPath: String {
        return NSTemporaryDirectory()
    }
    
    static var temporaryDirectoryURL: URL {
        return URL(fileURLWithPath: temporaryDirectoryPath, isDirectory: true)
    }
    
    @discardableResult
    static func createDirectory(atPath path: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    static func createDirectory(at url: URL) -> Bool {
        return createDirectory(atPath: url.path)
    }
    
    @discardableResult
    static func removeItem(atPath path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch {
            return false
        }
    }
    
    @discardableResult
    static func removeItem(at url: URL) -> Bool {
        return removeItem(atPath: url.path)
    }
    
    @discardableResult
    static func removeAllItemInsideDirectory(atPath path: String) -> Bool {
        let enumerator = FileManager.default.enumerator(atPath: path)
        var result = true
        while let fileName = enumerator?.nextObject() as? String {
            let success = removeItem(atPath: path + "/\(fileName)")
            if !success { result = false }
        }
        
        return result
    }
    
    @discardableResult
    static func removeAllItemInsideDirectory(at url: URL) -> Bool {
        return removeAllItemInsideDirectory(atPath: url.path)
    }
}

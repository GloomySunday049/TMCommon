//
//  HelpingMapper.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

public class HelpingMapper {
    private var mapping = Dictionary<Int, (String?, ((String) -> ())?)>()
    
    public func specify<T>(property: inout T, name: String) {
        let key = withUnsafePointer(to: &property, { return $0 }).hashValue
        self.mapping[key] = (name, nil)
    }
    
    public func specify<T>(property: inout T, converter: @escaping (String) -> T) {
        let pointer = withUnsafePointer(to: &property, { return $0 })
        let key = pointer.hashValue
        let assign = { (rawValue: String) in
            UnsafeMutablePointer<T>(mutating: pointer).pointee = converter(rawValue)
        }
        
        self.mapping[key] = (nil, assign)
    }
    
    public func specify<T>(property: inout T, name: String, converter: @escaping (String) -> T) {
        let pointer = withUnsafePointer(to: &property, { return $0 })
        let key = pointer.hashValue
        let assign = { (rawValue: String) in
            UnsafeMutablePointer<T>(mutating: pointer).pointee = converter(rawValue)
        }
        
        self.mapping[key] = (name, assign)
    }
    
    internal func getNameAndConverter(key: Int) -> (String?, ((String) -> ())?)? {
        return mapping[key]
    }
}

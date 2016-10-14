//
//  Converter.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

extension NSObject {
    
    func  toInt8() -> Int8? {
        if self is NSString {
            return Int8((self as! NSString) as String)
        }
        
        if self is NSNumber {
            return (self as! NSNumber).int8Value
        }
        
        return nil
    }
    
    func toUInt8() -> UInt8? {
        if self is NSString {
            return UInt8((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).uint8Value
        }
        return nil
    }
    
    func toInt16() -> Int16? {
        if self is NSString {
            return Int16((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).int16Value
        }
        return nil
    }
    
    func toUInt16() -> UInt16? {
        if self is NSString {
            return UInt16((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).uint16Value
        }
        return nil
    }
    
    func toInt32() -> Int32? {
        if self is NSString {
            return Int32((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).int32Value
        }
        return nil
    }
    
    func toUInt32() -> UInt32? {
        if self is NSString {
            return UInt32((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).uint32Value
        }
        return nil
    }
    
    func toInt64() -> Int64? {
        if self is NSString {
            return Int64((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).int64Value
        }
        return nil
    }
    
    func toUInt64() -> UInt64? {
        if self is NSString {
            return UInt64((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).uint64Value
        }
        return nil
    }
    
    func toBool() -> Bool? {
        if self is NSString {
            let lowerCase = ((self as! NSString) as String).lowercased()
            if ["0", "false"].contains(lowerCase) {
                return false
            }
            if ["1", "true"].contains(lowerCase) {
                return true
            }
        }
        if self is NSNumber {
            return (self as! NSNumber).boolValue
        }
        return nil
    }
    
    func toInt() -> Int? {
        if self is NSString {
            return Int((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).intValue
        }
        return nil
    }
    
    func toUInt() -> UInt? {
        if self is NSString {
            return UInt((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).uintValue
        }
        return nil
    }
    
    func toFloat() -> Float? {
        if self is NSString {
            return Float((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).floatValue
        }
        return nil
    }
    
    func toDouble() -> Double? {
        if self is NSString {
            return Double((self as! NSString) as String)
        }
        if self is NSNumber {
            return (self as! NSNumber).doubleValue
        }
        return nil
    }
    
    func toString() -> String? {
        if self is NSString {
            return (self as! NSString) as String
        }
        return nil
    }
    
    func toNSString() -> NSString? {
        if self is NSString {
            return self as? NSString
        }
        if self is NSNumber {
            return (self as! NSNumber).stringValue as NSString
        }
        return nil
    }
    
    func toNSNumber() -> NSNumber? {
        if self is NSNumber {
            return self as? NSNumber
        }
        if self is NSString {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.number(from: (self as? NSString)! as String)
        }
        return nil
    }
    
    func toStringForcedly() -> String {
        if self is NSNull {
            return "null"
        } else if self is NSString {
            return self as! String
        } else if self is NSNumber {
            return (self as! NSNumber).stringValue
        } else if self is NSArray {
            return "\(self as! NSArray)"
        } else if self is NSDictionary {
            return "\(self as! NSDictionary)"
        }
        
        return "null"
    }
}

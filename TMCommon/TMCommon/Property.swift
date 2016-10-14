//
//  Property.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

typealias Byte  = Int8

public protocol TranslatePropertiable {
}

extension TranslatePropertiable {
    
    mutating func headPointerOfStruct() -> UnsafePointer<Byte> {
        return withUnsafePointer(to: &self) {
            return UnsafeRawPointer($0).bindMemory(to: Byte.self, capacity: MemoryLayout<Self>.stride)
        }
    }
    
    mutating func headPointerOfClass() -> UnsafePointer<Byte> {
        let opaquePointer = Unmanaged.passUnretained(self as AnyObject).toOpaque()
        let mutableTypePointer = opaquePointer.bindMemory(to: Byte.self, capacity: MemoryLayout<Self>.stride)
        return UnsafePointer<Byte>(mutableTypePointer)
    }
    
    static func size() -> Int {
        return MemoryLayout<Self>.size
    }
    
    static func align() -> Int {
        return MemoryLayout<Self>.alignment
    }
    
    static func offsetOfAlignment(value: Int, align: Int) -> Int {
        let m = value % align
        return m == 0 ? 0 : (align - m)
    }
}

public protocol TMJSON : TranslatePropertiable {
    init()
    mutating func mapping(mapper: HelpingMapper)
}

public extension TMJSON {
    public mutating func mapping(mapper: HelpingMapper) {}
}

protocol  BasePropertyProtocol: TMJSON {
}

protocol OptionalTypeProtocol: TMJSON {
    static func getWrappedType() -> Any.Type
}

extension Optional: OptionalTypeProtocol {
    
    public init() {
        self = nil
    }
    
    static func getWrappedType() -> Any.Type {
        return Wrapped.self
    }
}

protocol ImplicitlyUnwrappedTypeProtocol: TMJSON {
    static func getWrappedType() -> Any.Type
}

extension ImplicitlyUnwrappedOptional: ImplicitlyUnwrappedTypeProtocol {
    
    static func getWrappedType() -> Any.Type {
        return Wrapped.self
    }
}

protocol ArrayTypeProtocol: TMJSON {
    static func getWrappedType() -> Any.Type
    static func castArrayType(arr: [Any]) -> Self
}

extension Array: ArrayTypeProtocol {
    
    static func getWrappedType() -> Any.Type {
        return Element.self
    }
    
    static func castArrayType(arr: [Any]) -> Array<Element> {
        return arr.map {
            return $0 as! Element
        }
    }
}

protocol DictionaryTypeProtocol: TMJSON {
    static func getWrappedIndexType() -> Any.Type
    static func getWrappedValueType() -> Any.Type
    static func caseDictionaryType(dic: [String : Any]) -> Self
}

extension Dictionary: DictionaryTypeProtocol {
    
    static func getWrappedIndexType() -> Any.Type {
        return Key.self
    }
    
    static func getWrappedValueType() -> Any.Type {
        return Value.self
    }
    
    static func caseDictionaryType(dic: [String : Any]) -> Dictionary<Key, Value> {
        var result = Dictionary<Key, Value>()
        dic.forEach {
            if let key = $0.key as? Key, let value = $0.value as? Value {
                result[key] = value
            }
        }
        
        return result
    }
}

extension NSArray: TranslatePropertiable {}
extension NSDictionary: TranslatePropertiable {}

extension TranslatePropertiable {
    
    public static func tm_transform(dic: NSDictionary, toType type: TMJSON.Type) -> TMJSON {
        var instance = type.init()
        let mirror = Mirror(reflecting: instance)
        guard let dStyle = mirror.displayStyle else {
            fatalError("Target type must has a display type")
        }
        
        var pointer: UnsafePointer<Byte>!
        let mapper = HelpingMapper()
        var currentOffset = 0
        instance.mapping(mapper: mapper)
        if dStyle == .class {
            pointer = instance.headPointerOfClass()
            currentOffset = 8 + MemoryLayout<Int>.size
        } else if dStyle == .struct {
            pointer = instance.headPointerOfStruct()
        } else {
            fatalError("Target obejct must be class or struct")
        }
        
        _ = tm_transform(rawData: dic, toPointer: pointer, toOffset: currentOffset, byMirror: mirror, withMapper: mapper)
        
        return instance
    }
    
    internal static func tm_transform(rawData dic: NSDictionary, toPointer pointer: UnsafePointer<Byte>, toOffset currentOffset: Int, byMirror mirror: Mirror, withMapper mapper: HelpingMapper) -> Int {
        var currentOffset = currentOffset
        if let superMirror = mirror.superclassMirror {
            currentOffset = tm_transform(rawData: dic, toPointer: pointer, toOffset: currentOffset, byMirror: superMirror, withMapper: mapper)
        }
        
        var mutablePointer = pointer.advanced(by: currentOffset)
        mirror.children.forEach {
            var offset = 0, size = 0
            guard let propertyType = type(of: $0.value) as? TranslatePropertiable.Type else {
                print("label: ", $0.label ?? "", "type: ", "\(type(of: $0.value))")
                fatalError("Each property should be tmjson-property type")
            }
            
            size = propertyType.size()
            offset = propertyType.offsetOfAlignment(value: currentOffset, align: propertyType.align())
            mutablePointer = mutablePointer.advanced(by: offset)
            currentOffset += offset
            guard let label = $0.label else {
                mutablePointer = mutablePointer.advanced(by: size)
                currentOffset += size
                return
            }
            
            var key = label
            if let converter = mapper.getNameAndConverter(key: mutablePointer.hashValue) {
                if let specifyKey = converter.0 {
                    key = specifyKey
                }
                
                if let specifyConverter = converter.1 {
                    if let ocValue = (dic[key] as? NSObject)?.toStringForcedly() {
                        specifyConverter(ocValue)
                    }
                    
                    mutablePointer = mutablePointer.advanced(by: size)
                    currentOffset += size
                    return
                }
            }
            
            guard let value = dic[key] as? NSObject else {
                mutablePointer = mutablePointer.advanced(by: size)
                currentOffset += size
                return
            }
            
            if let sv = propertyType.valueFrom(object: value) {
                propertyType.codeIntoMemory(pointer: mutablePointer, value: sv)
            }
            
            mutablePointer = mutablePointer.advanced(by: size)
            currentOffset += size
        }
        
        return currentOffset
    }
    
    static func valueFrom(object: NSObject) -> Self? {
        if self is BasePropertyProtocol.Type {
            return baseValueFrom(object: object)
        } else if self is OptionalTypeProtocol.Type {
            return optionalValueFrom(object: object)
        } else if self is ImplicitlyUnwrappedTypeProtocol.Type {
            return implicitUnwrappedValueFrom(object: object)
        } else if self is ArrayTypeProtocol.Type {
            if let value = arrayValueFrom(object: object) {
                return (self as! ArrayTypeProtocol.Type).castArrayType(arr: value) as? Self
            }
        } else if self is DictionaryTypeProtocol.Type {
            if let dic = dicValueFrom(object: object) {
                return (self as! DictionaryTypeProtocol.Type).caseDictionaryType(dic: dic) as? Self
            }
        } else if self is NSArray.Type {
            if let arr = object as? NSArray {
                return arr as? Self
            }
        } else if self is NSDictionary.Type {
            if let dic = object as? NSDictionary {
                return dic as? Self
            }
        } else if self is TMJSON.Type {
            if let dic = object as? NSDictionary {
                return tm_transform(dic: dic, toType: self as! TMJSON.Type) as? Self
            }
        }
        
        return nil
    }
    
    static func baseValueFrom(object: NSObject) -> Self? {
        switch self {
        case is Int8.Type:
            return object.toInt8() as? Self
        case is UInt8.Type:
            return object.toUInt8() as? Self
        case is Int16.Type:
            return object.toInt16() as? Self
        case is UInt16.Type:
            return object.toUInt16() as? Self
        case is Int32.Type:
            return object.toInt32() as? Self
        case is UInt32.Type:
            return object.toUInt32() as? Self
        case is Int64.Type:
            return object.toInt64() as? Self
        case is UInt64.Type:
            return object.toUInt64() as? Self
        case is Bool.Type:
            return object.toBool() as? Self
        case is Int.Type:
            return object.toInt() as? Self
        case is UInt.Type:
            return object.toUInt() as? Self
        case is Float.Type:
            return object.toFloat() as? Self
        case is Double.Type:
            return object.toDouble() as? Self
        case is String.Type:
            return object.toString() as? Self
        case is NSString.Type:
            return object.toNSString() as? Self
        case is NSNumber.Type:
            return object.toNSNumber() as? Self
        default:
            break
        }
        return nil
    }
    
    static func optionalValueFrom(object: NSObject) -> Self? {
        if let wrappedType = (self as! OptionalTypeProtocol.Type).getWrappedType() as? TranslatePropertiable.Type {
            if let value = wrappedType.valueFrom(object: object) {
                return wrappedType.wrapByOptional(value: value) as? Self
            }
        }
        
        return nil
    }
    
    static func implicitUnwrappedValueFrom(object: NSObject) -> Self? {
        if let wrappedType = (self as! ImplicitlyUnwrappedTypeProtocol.Type).getWrappedType() as? TranslatePropertiable.Type {
            if let value = wrappedType.valueFrom(object: object) {
                return wrappedType.wrapByImplicitUnwrapped(value: value) as? Self
            }
        }
        
        return nil
    }
    
    static func wrapByOptional(value: TranslatePropertiable) -> Optional<Self> {
        return Optional(value as! Self)
    }
    
    static func wrapByImplicitUnwrapped(value: TranslatePropertiable) -> ImplicitlyUnwrappedOptional<Self> {
        return ImplicitlyUnwrappedOptional(value as! Self)
    }
    
    static func arrayValueFrom(object: NSObject) -> [Any]? {
        if let wrappedType = (self as! ArrayTypeProtocol.Type).getWrappedType() as? TranslatePropertiable.Type {
            if let arr = object as? NSArray {
                return wrappedType.composeToArray(nsArray: arr)
            }
        }
        
        return nil
    }
    
    static func composeToArray(nsArray: NSArray) -> [Any] {
        var arr = [Any]()
        nsArray.forEach {
            if let nsObject = $0 as? NSObject {
                let v = valueFrom(object: nsObject)
                arr.append(v)
            }
        }
        
        return arr
    }
    
    static func dicValueFrom(object: NSObject) -> [String : Any]? {
        if let wrappedValueType = (self as! DictionaryTypeProtocol.Type).getWrappedValueType() as? TranslatePropertiable.Type {
            if let dic = object as? NSDictionary {
                return wrappedValueType.compostToDictionary(nsDic: dic)
            }
        }
        
        return nil
    }
    
    static func compostToDictionary(nsDic: NSDictionary) -> [String : Any] {
        var dic = [String : Any]()
        nsDic.forEach {
            if let key = $0.key as? String, let valueObj = $0.value as? NSObject, let value = valueFrom(object: valueObj) {
                dic[key] = value
            }
        }
        
        return dic
    }
    
    static func codeIntoMemory(pointer: UnsafePointer<Byte>, value: TranslatePropertiable) {
        pointer.withMemoryRebound(to: Self.self, capacity: 1, { return $0 }).pointee = value as! Self
    }
}



//
//  JSONSerializer.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

public class JSONSerializer {
    
    public static func serializeToJSON(object: Any?, prettify: Bool = false) -> String? {
        if let _object = object {
            var json = tm_serializeToJSON(object: _object)
            if prettify {
                let jsonData = json.data(using: .utf8)!
                let jsonObject:AnyObject = try! JSONSerialization.jsonObject(with: jsonData, options: []) as AnyObject
                let prettyJsonData = try! JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted)
                json = NSString(data: prettyJsonData, encoding: String.Encoding.utf8.rawValue)! as String
            }
            
            return json
        } else {
            return nil
        }
    }
    
    static func tm_serializeToJSON(object: Any) -> String {
        if type(of: object) is String.Type || type(of: object) is NSString.Type {
            let json = "\"" + String(describing: object) + "\""
            return json
        } else if type(of: object) is BasePropertyProtocol.Type {
            return String(describing: object)
        }
        
        var json = String()
        let mirror = Mirror(reflecting: object)
        if mirror.displayStyle == .class || mirror.displayStyle == .struct {
            var handledValue = String()
            var children = [(label: String?, value: Any)]()
            let mirrorChildrenCollection = AnyRandomAccessCollection(mirror.children)!
            children += mirrorChildrenCollection
            var currentMirror = mirror
            while let superClassChildren = currentMirror.superclassMirror?.children {
                let randomCollection = AnyRandomAccessCollection(superClassChildren)!
                children += randomCollection
                currentMirror = currentMirror.superclassMirror!
            }
            
            children.enumerated().forEach {
                handledValue = tm_serializeToJSON(object: $0.element.value)
                json += "\"\($0.element.label ?? "")\":\(handledValue)" + ($0.offset < children.count - 1 ? "," : "")
            }
            
            return "{" + json + "}"
        } else if mirror.displayStyle == .enum {
            return "\"" + String(describing: object) + "\""
        } else if mirror.displayStyle == .optional {
            if mirror.children.count != 0 {
                let (_, some) = mirror.children.first!
                return tm_serializeToJSON(object: some)
            } else {
                return "null"
            }
        } else if mirror.displayStyle == .collection || mirror.displayStyle == .set {
            json = "["
            let count = mirror.children.count
            mirror.children.enumerated().forEach {
                let transformValue = tm_serializeToJSON(object: $0.element.value)
                json += transformValue
                json += ($0.offset < count - 1 ? "," : "")
            }
            
            json += "]"
            return json
        } else if mirror.displayStyle == .dictionary {
            json += "{"
            mirror.children.enumerated().forEach {
                let _index = $0.offset
                let _mirror = Mirror(reflecting: $0.element.value)
                _mirror.children.enumerated().forEach {
                    if $0.offset == 0 {
                        json += tm_serializeToJSON(object: $0.element.value) + ":"
                    } else {
                        json += tm_serializeToJSON(object: $0.element.value)
                        json += (_index < mirror.children.count - 1 ? "," : "")
                    }
                }
            }
            
            json += "}"
            return json
        } else {
            return String(describing: object) != "nil" ? "\"\(object)\"" : "null"
        }
    }
}

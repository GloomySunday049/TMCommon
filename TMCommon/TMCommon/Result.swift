//
//  Result.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/17.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import Foundation

// MARK: Result

public enum Result<Value> {
    
    case success(Value)
    case failure(Error)
    
    public var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    public var isFailure: Bool {
        return !isSuccess
    }
    
    public var value: Value? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    public var error: Error? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error
        }
    }
}

// MARK: CustomStringConvertible

extension Result: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .success:
            return "SUCCESS"
        case .failure:
            return "FAILURE"
        }
    }
}

// MARK: CustomDebugStringConvertible

extension Result: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        switch self {
        case .success(let value):
            return "SUCCESS: \(value)"
        case .failure(let error):
            return "FAILURE: \(error)"
        }
    }
}

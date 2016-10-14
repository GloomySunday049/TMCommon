//
//  MemoryLayoutValidationTest.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon

class MemoryLayoutValidationTest: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testHeadOfClass() {
        class A {
            var m1: Int8 = 0
        }
        
        let a = A()
        let basePtr = Unmanaged.passUnretained(a).toOpaque().advanced(by: 8 + MemoryLayout<Int>.size)
        let realPtr = UnsafeMutablePointer<Int8>(bitPattern: basePtr.hashValue)
        realPtr?.pointee = 11
        XCTAssert(a.m1 == 11)
    }
    
    func testHeadOfStruct() {
        struct B {
            var m1: Int8 = 0
        }
        
        var b = B()
        let basePtr = UnsafePointer<Int8>(bitPattern: withUnsafePointer(to: &b, {
            return UnsafeRawPointer($0).bindMemory(to: Int8.self, capacity: MemoryLayout<B>.stride)
        }).hashValue)
        let realPtr = UnsafeMutablePointer<Int8>(bitPattern: basePtr?.hashValue ?? 0)
        realPtr?.pointee = 11
        XCTAssert(b.m1 == 11)
    }
    
}

//
//  ClassObjectTest.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon

class ClassObjectTest: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSimpleClass() {
        class A: TMJSON {
            var name: String?
            var id: String?
            var height: Int?
            
            required init() {}
        }
        
        let jsonString = "{\"name\":\"Bob\",\"id\":\"12345\",\"height\":180}"
        guard let a = JSONDeserializer<A>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(a.name == "Bob")
        XCTAssert(a.id == "12345")
        XCTAssert(a.height == 180)
    }
    
    func testClassWithArrayProperty() {
        class B: NSObject, TMJSON {
            var id: Int?
            var arr1: Array<Int>?
            var arr2: Array<String>?
            
            required override init() {}
        }
        
        let jsonString = "{\"id\":123456,\"arr1\":[1,2,3,4,5,6],\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        guard let b = JSONDeserializer<B>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(b.id == 123456)
        XCTAssert(b.arr1?.count == 6)
        XCTAssert(b.arr2?.count == 5)
        XCTAssert(b.arr1?.last == 6)
        XCTAssert(b.arr2?.last == "e")
    }
    
    func testClassWithImplicitlyUnwrappedOptionalProperty() {
        class C: NSObject, TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String>?
            
            required override init() {}
        }
        
        let jsonString = "{\"id\":123456,\"arr1\":[1,2,3,4,5,6],\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        guard let c = JSONDeserializer<C>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(c.id == 123456)
        XCTAssert(c.arr1.count == 6)
        XCTAssert(c.arr2?.count == 5)
        XCTAssert((c.arr1.last ?? 0) == 6)
        XCTAssert(c.arr2?.last == "e")
    }
    
    func testClassWithDummyProperty() {
        class C: NSObject, TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String>?
            
            required override init() {}
        }
        class D: TMJSON {
            var dummy1: String?
            var id: Int!
            var arr1: Array<Int>?
            var dummy2: C?
            var arr2: Array<String> = Array<String>()
            var dummy3: C!
            
            required init() {}
        }
        
        let jsonString = "{\"id\":123456,\"arr1\":[1,2,3,4,5,6],\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        guard let d = JSONDeserializer<D>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(d.id == 123456)
        XCTAssert(d.arr1?.count == 6)
        XCTAssert(d.arr2.count == 5)
        XCTAssert(d.arr1?.last == 6)
        XCTAssert(d.arr2.last == "e")
    }
    
    func testClassWithDummyJsonField() {
        class E: TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String>?
            
            required init() {}
        }
        
        let jsonString = "{\"id\":123456,\"dummy1\":23334,\"arr1\":[1,2,3,4,5,6],\"dummy2\":\"string\",\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        guard let e = JSONDeserializer<E>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(e.id == 123456)
        XCTAssert(e.arr1.count == 6)
        XCTAssert(e.arr2?.count == 5)
        XCTAssert((e.arr1.last ?? 0) == 6)
        XCTAssert(e.arr2?.last == "e")
    }
    
    func testOptionalClass() {
        class A: TMJSON {
            var name: String?
            var id: String?
            var height: Int?
            
            required init() {}
        }
        
        var jsonString: String? = "{\"name\":\"Bob\",\"id\":\"12345\",\"height\":180}"
        guard let a = JSONDeserializer<A>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(a.name == "Bob")
        XCTAssert(a.id == "12345")
        XCTAssert(a.height == 180)
        
        jsonString = nil
        
        if let _ = JSONDeserializer<A>.deserializeFrom(json: jsonString) {
            XCTAssert(false)
        } else {
            XCTAssert(true)
        }
    }
    
}

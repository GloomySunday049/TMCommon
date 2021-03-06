//
//  StructObjectTest.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon

class StructObjectTest: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSimpleStruct() {
        struct A: TMJSON {
            var name: String?
            var id: String?
            var height: Int?
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
    
    func testStructWithArrayProperty() {
        struct B: TMJSON {
            var id: Int?
            var arr1: Array<Int>?
            var arr2: Array<String>?
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
    
    func testStructWithiImpliicitlyUnwrappedOptionalProperty() {
        struct C: TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String?>?
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
        XCTAssert((c.arr2?.last ?? "") == "e")
    }
    
    func testStructWithDummyProperty() {
        struct C: TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String?>?
        }
        struct D: TMJSON {
            var dummy1: String?
            var id: Int!
            var arr1: Array<Int>?
            var dummy2: C?
            var arr2: Array<String> = Array<String>()
            var dumimy3: C!
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
    
    func testStructWithiDummyiJsonField() {
        struct E: TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String?>?
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
        XCTAssert((e.arr2?.last ?? "") == "e")
    }
    
    func testStructWithiDesiginatePath() {
        struct F: TMJSON {
            var id: Int?
            var arr1: Array<Int?>!
            var arr2: Array<String?>?
        }
        
        let jsonString = "{\"data\":{\"result\":{\"id\":123456,\"arr1\":[1,2,3,4,5,6],\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}},\"code\":200}"
        guard let f = JSONDeserializer<F>.deserializeFrom(json: jsonString, designatedPath: "data.result") else {
            XCTAssert(false)
            return
        }
        XCTAssert(f.id == 123456)
        XCTAssert(f.arr1.count == 6)
        XCTAssert(f.arr2?.count == 5)
        XCTAssert((f.arr1.last ?? 0) == 6)
        XCTAssert((f.arr2?.last ?? "") == "e")
    }
}

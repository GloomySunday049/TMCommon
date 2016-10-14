//
//  ObjectiveCObjectTest.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon

class ObjectiveCObjectTest: BaseTestCase {
    
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
            var name: NSString?
            var id: NSString?
            var height: NSNumber?
            
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
        class B: TMJSON {
            var arr1: NSArray?
            var arr2: NSArray?
            var id: Int?
            
            required init() {}
        }
        
        let jsonString = "{\"id\":123456,\"arr1\":[1,2,3,4,5,6],\"arr2\":[\"a\",\"b\",\"c\",\"d\",\"e\"]}"
        guard let b = JSONDeserializer<B>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(b.id == 123456)
        XCTAssert(b.arr1?.count == 6)
        XCTAssert(b.arr2?.count == 5)
        XCTAssert((b.arr1?.object(at: 5) as? NSNumber)?.intValue == 6)
        XCTAssert((b.arr2?.object(at: 4) as? NSString)?.isEqual(to: "e") == true)
    }
}

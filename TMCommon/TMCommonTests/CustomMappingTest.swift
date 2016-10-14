//
//  CustomMappingTest.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon

class CustomMappingTest: BaseTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testStructMapping() {
        
        struct A: TMJSON {
            var name: String?
            var id: String?
            var height: Int?
            
            mutating func mapping(mapper: HelpingMapper) {
                // specify json field name
                mapper.specify(property: &name, name: "json_name")
                
                // specify converting method
                mapper.specify(property: &id, converter: { rawValue -> String in
                    return "json_" + rawValue
                })
                
                // specify both
                mapper.specify(property: &height, name: "json_height", converter: { rawValue -> Int in
                    print("classMapping: ", rawValue)
                    return Int(rawValue) ?? 0
                })
            }
        }
        
        let jsonString = "{\"json_name\":\"Bob\",\"id\":\"12345\",\"json_height\":180}"
        guard let a = JSONDeserializer<A>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        print(a)
        XCTAssert(a.name == "Bob")
        XCTAssert(a.id == "json_12345")
        XCTAssert(a.height == 180)
    }
    
    func testClassMapping() {
        
        class A: TMJSON {
            var name: String?
            var id: String?
            var height: Int?
            
            required init() {}
            
            func mapping(mapper: HelpingMapper) {
                // specify json field name
                mapper.specify(property: &name, name: "json_name")
                
                // specify converting method
                mapper.specify(property: &id, converter: { rawValue -> String in
                    return "json_" + rawValue
                })
                
                // specify both
                mapper.specify(property: &height, name: "json_height", converter: { rawValue -> Int? in
                    print("classMapping: ", rawValue)
                    return Int(rawValue)
                })
            }
        }
        
        let jsonString = "{\"json_name\":\"Bob\",\"id\":\"12345\",\"json_height\":180}"
        guard let a = JSONDeserializer<A>.deserializeFrom(json: jsonString) else {
            XCTAssert(false)
            return
        }
        XCTAssert(a.name == "Bob")
        XCTAssert(a.id == "json_12345")
        XCTAssert(a.height == 180)
    }
    
}

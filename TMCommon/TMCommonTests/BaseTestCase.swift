//
//  BaseTestCase.swift
//  TMCommon
//
//  Created by 孟钰丰 on 2016/10/14.
//  Copyright © 2016年 Petsknow. All rights reserved.
//

import XCTest
import TMCommon
import Foundation

class BaseTestCase: XCTestCase {
    let timeout: TimeInterval = 30
    
    static var testDirectoryURL: URL { return FileManager.temporaryDirectoryURL.appendingPathComponent("cn.petsknow.tests") }
    var testDirectoryURL: URL { return BaseTestCase.testDirectoryURL }
    
    override func startMeasuring() {
        
    }
    
    override func setUp() {
        super.setUp()
        
        FileManager.removeAllItemInsideDirectory(at: testDirectoryURL)
        FileManager.createDirectory(at: testDirectoryURL)
    }
    
    func url(forResource fileName: String, withExtension ext: String) -> URL {
        let bundle = Bundle(for: BaseTestCase.self)
        return bundle.url(forResource: fileName, withExtension: ext)!
    }
    
}

//
//  EPUBTest.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation

import XCTest
@testable import EPUBKit

final class EPUBTests: XCTestCase {
    static var allTests = [
        ("testEPUBInitDirectory", testEPUBInitDirectory),
        ("testEPUBInitZIP", testEPUBInitZIP),
    ]
}

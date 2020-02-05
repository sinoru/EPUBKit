//
//  EPUBTest.swift
//  
//

//

import Foundation
import XCTest

@testable import EPUBKit

final class EPUBTests: XCTestCase {
    static var allTests = [
        ("testEPUBInitDirectory", testEPUBInitDirectory),
        ("testEPUBInitZIP", testEPUBInitZIP),
        ("testEPUBOpenZIP", testEPUBOpenZIP)
    ]
}

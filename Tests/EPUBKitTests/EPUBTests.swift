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
    func testEPUBInit() {
        XCTAssertNoThrow(try EPUB(fileURL: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("jikji.epub+zip.epub")))
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(EPUBKit().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}

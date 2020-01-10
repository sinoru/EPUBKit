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
    func testEPUBInit() throws {
        let epub = try EPUB(fileURL: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("jikji.epub+zip.epub"))

        let expectation = XCTestExpectation()

        let observationForState = epub.$state.sink {
            switch $0 {
            case .normal:
                XCTAssertEqual(epub.metadata?.title, "직지 프로젝트")
                XCTAssertEqual(epub.metadata?.creator, "수학방")
                expectation.fulfill()
            default:
                break
            }
        }

        wait(for: [expectation], timeout: 100.0)
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

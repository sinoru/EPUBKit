//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation

import XCTest
@testable import EPUBKit

extension EPUBTests {
    func testEPUBInitDirectory() throws {
        let epub = try EPUB(fileURL: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("jikji.epub"))

        let expectation = XCTestExpectation()

        let observationForState = epub.$state.sink {
            switch $0 {
            case .closed:
                XCTAssertEqual(epub.metadata?.title, "직지 프로젝트")
                XCTAssertEqual(epub.metadata?.creator, "수학방")
                expectation.fulfill()
            default:
                break
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}

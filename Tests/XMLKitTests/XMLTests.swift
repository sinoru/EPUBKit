//
//  XMLTests.swift
//  
//

//

import Foundation

import XCTest
@testable import XMLKit

final class XMLTests: XCTestCase {
    func testXMLInitNote() throws {
        let xmlData = try Data(
            contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("note.xml")
        )

        let xmlParseOperation = XMLParseOperation(data: xmlData)
        xmlParseOperation.start()

        let xmlDocument = xmlParseOperation.xmlDocument

        XCTAssertEqual(xmlDocument.elements.count, 1)
        XCTAssertEqual(xmlDocument.elements[0].elementName, "note")
        XCTAssertEqual(xmlDocument.elements[0].childeren.count, 4)
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].elementName, "to")
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].character, "Tove")
        XCTAssertEqual(xmlDocument.elements[0].childeren[1].elementName, "from")
        XCTAssertEqual(xmlDocument.elements[0].childeren[1].character, "Jani")
        XCTAssertEqual(xmlDocument.elements[0].childeren[2].elementName, "heading")
        XCTAssertEqual(xmlDocument.elements[0].childeren[2].character, "Reminder")
        XCTAssertEqual(xmlDocument.elements[0].childeren[3].elementName, "body")
        XCTAssertEqual(xmlDocument.elements[0].childeren[3].character, "Don't forget me this weekend!")
    }

    func testXMLInitContainer() throws {
        let xmlData = try Data(
            contentsOf: URL(fileURLWithPath: #file)
                .deletingLastPathComponent()
                .appendingPathComponent("container.xml")
        )

        let xmlParseOperation = XMLParseOperation(data: xmlData)
        xmlParseOperation.start()

        let xmlDocument = xmlParseOperation.xmlDocument

        XCTAssertEqual(xmlDocument.elements.count, 1)
        XCTAssertEqual(xmlDocument.elements[0].elementName, "container")
        XCTAssertEqual(xmlDocument.elements[0].attributes, [
            "xmlns": "urn:oasis:names:tc:opendocument:xmlns:container",
            "version": "1.0"
        ])
        XCTAssertEqual(xmlDocument.elements[0].childeren.count, 1)
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].elementName, "rootfiles")
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].attributes, [:])
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].childeren.count, 1)
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].childeren[0].elementName, "rootfile")
        XCTAssertEqual(xmlDocument.elements[0].childeren[0].childeren[0].attributes, [
            "full-path": "OEBPS/content.opf",
            "media-type": "application/oebps-package+xml"
        ])
    }

    func testXMLSubscriptByElementsName() throws {
        let xmlData = try Data(contentsOf: URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("note.xml"))

        let xmlParseOperation = XMLParseOperation(data: xmlData)
        xmlParseOperation.start()

        let xmlDocument = xmlParseOperation.xmlDocument

        XCTAssertEqual(xmlDocument["note", "to"]?.elementName, "to")
        XCTAssertEqual(xmlDocument["note", "to"]?.character, "Tove")
        XCTAssertEqual(xmlDocument["note", "body"]?.elementName, "body")
        XCTAssertEqual(xmlDocument["note", "body"]?.character, "Don't forget me this weekend!")
    }

    static var allTests = [
        ("testXMLInitNote", testXMLInitNote),
        ("testXMLInitContainer", testXMLInitContainer)
    ]
}

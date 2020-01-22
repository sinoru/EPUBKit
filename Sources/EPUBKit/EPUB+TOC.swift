//
//  EPUB+TOC.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation
import XMLKit

extension EPUB {
    public struct TOC {
        var items: [Item]
    }
}

extension EPUB.TOC {
    init(ncxXMLDocument: XMLKit.XMLDocument) throws {
        guard let ncx = ncxXMLDocument["ncx"] else {
            throw EPUB.Error.invalidEPUB
        }

        self.items = try (ncx["navMap"]?.childeren.map {
            try Item(navPointXMLElement: $0)
        } ?? [])
    }
}

extension EPUB.TOC {
    public struct Item {
        var name: String
        var contentURL: URL
        var playOrder: Int
        var children: [Item]
    }
}

extension EPUB.TOC.Item {
    init(navPointXMLElement: XMLKit.XMLElement) throws {
        guard let name = navPointXMLElement["navLabel", "text"]?.character else {
            throw EPUB.Error.invalidEPUB
        }
        self.name = name

        guard let contentURL = navPointXMLElement["content"].flatMap({ $0.attributes["src"] }).flatMap({ URL(string: $0) }) else {
            throw EPUB.Error.invalidEPUB
        }
        self.contentURL = contentURL

        guard let playOrder = navPointXMLElement.attributes["playOrder"].flatMap({ Int($0) }) else {
            throw EPUB.Error.invalidEPUB
        }
        self.playOrder = playOrder

        self.children = try navPointXMLElement.childeren
            .filter { $0.elementName == "navPoint" }
            .map { try EPUB.TOC.Item(navPointXMLElement: $0) }
    }
}

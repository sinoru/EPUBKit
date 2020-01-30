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
        public var name: String
        public var epubItemURL: URL
        public var playOrder: Int
        public var children: [Item]
    }
}

extension EPUB.TOC.Item {
    init(navPointXMLElement: XMLKit.XMLElement) throws {
        guard let name = navPointXMLElement["navLabel", "text"]?.character else {
            throw EPUB.Error.invalidEPUB
        }
        self.name = name

        guard let epubItemURL = navPointXMLElement["content"].flatMap({ $0.attributes["src"] }).flatMap({ URL(string: $0) }) else {
            throw EPUB.Error.invalidEPUB
        }
        self.epubItemURL = epubItemURL

        guard let playOrder = navPointXMLElement.attributes["playOrder"].flatMap({ Int($0) }) else {
            throw EPUB.Error.invalidEPUB
        }
        self.playOrder = playOrder

        self.children = try navPointXMLElement.childeren
            .filter { $0.elementName == "navPoint" }
            .map { try EPUB.TOC.Item(navPointXMLElement: $0) }
    }
}

extension EPUB.TOC {
    public func flattenKeyPaths() -> [(depth: Int, playOrder: Int, keyPath: KeyPath<EPUB.TOC, EPUB.TOC.Item>)] {
        items._flatten(depth: 0, keyPath: \.items)
    }
}

extension Array where Element == EPUB.TOC.Item {
    fileprivate func _flatten(depth: Int, keyPath: KeyPath<EPUB.TOC, [EPUB.TOC.Item]>) -> [(depth: Int, playOrder: Int, keyPath: KeyPath<EPUB.TOC, EPUB.TOC.Item>)] {
        enumerated().flatMap {
            [(depth: depth, playOrder: $1.playOrder, keyPath: keyPath.appending(path: \.[$0]))] + $1.children._flatten(depth: depth + 1, keyPath: keyPath.appending(path: \.[$0].children))
        }
    }
}

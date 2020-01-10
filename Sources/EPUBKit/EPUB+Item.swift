//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation
import XMLKit

extension EPUB {
    public struct Item: Identifiable {
        public var id: String
        public var path: String
        public var mimeType: String
    }
}

extension EPUB.Item {
    static func items(manifestXMLElement: XMLKit.XMLElement) throws -> [Self] {
        return try manifestXMLElement.childeren.map {
            guard let id = $0.attributes["id"] else {
                throw EPUB.Error.invalidEPUB
            }

            guard let path = $0.attributes["href"] else {
                throw EPUB.Error.invalidEPUB
            }

            guard let mimeType = $0.attributes["media-type"] else {
                throw EPUB.Error.invalidEPUB
            }

            return .init(id: id, path: path, mimeType: mimeType)
        }
    }
}

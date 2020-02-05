//
//  EPUB+Spine.swift
//  EPUBKit
//

import Foundation
import XMLKit

extension EPUB {
    public struct Spine {
        public var tocItemID: String?
        public var itemRefs: [Item.Ref] = []
    }
}

extension EPUB.Spine {
    init(spineXMLElement: XMLKit.XMLElement) throws {
        self.tocItemID = spineXMLElement.attributes["toc"]
        self.itemRefs = try spineXMLElement.childeren.map {
            guard let idref = $0.attributes["idref"] else {
                throw EPUB.Error.invalidEPUB
            }

            return .init(id: idref)
        }
    }
}

//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation
import XMLKit

extension EPUB {
    public struct Spine {
        public var ncxTOC: NCXTOC?
        public var itemRefs: [Item.Ref] = []
    }
}

extension EPUB.Spine {
    init(spineXMLElement: XMLKit.XMLElement) throws {
        self.itemRefs = try spineXMLElement.childeren.map {
            guard let idref = $0.attributes["idref"] else {
                throw EPUB.Error.invalidEPUB
            }

            return .init(id: idref)
        }
    }
}

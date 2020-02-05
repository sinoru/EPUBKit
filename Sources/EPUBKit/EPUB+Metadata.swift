//
//  EPUB+Metadata.swift
//  EPUBKit
//

import Foundation
import SNFoundation
import XMLKit

extension EPUB {
    public struct Metadata {
        public var bookID: UUID = .empty
        public var title: String?
        public var creator: String?
    }
}

extension EPUB.Metadata {
    init(metadataXMLElement: XMLKit.XMLElement) {
        if
            let identifierElement = metadataXMLElement["dc:identifier"],
            let uuidComponents = identifierElement.character?.components(separatedBy: "urn:uuid:"),
            uuidComponents.count == 2,
            let uuid = UUID(uuidString: uuidComponents[1])
        {
            bookID = uuid
        } else {
            bookID = UUID.empty
        }

        title = metadataXMLElement["dc:title"]?.character
        creator = metadataXMLElement["dc:creator"]?.character
    }
}

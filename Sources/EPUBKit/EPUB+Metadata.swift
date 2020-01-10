//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation
import XMLKit

extension EPUB {
    public struct Metadata {
        public var title: String?
        public var creator: String?
    }
}

extension EPUB.Metadata {
    init(metadataXMLElement: XMLKit.XMLElement) {
        title = metadataXMLElement["dc:title"]?.character
        creator = metadataXMLElement["dc:creator"]?.character
    }
}

//
//  XMLParseOperation.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation

open class XMLParseOperation: Operation {
    var xmlParser: XMLParser

    public var xmlDocument = XMLDocument()
    private var xmlDocumentCurrentIndexPath = IndexPath()
    private var isNodeOpend: Bool = false

    public init(data: Data) {
        xmlParser = .init(data: data)
        super.init()

        xmlParser.delegate = self
    }

    override open func main() {
        xmlParser.parse()
    }
}

extension XMLParseOperation: XMLParserDelegate {
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        isNodeOpend = true

        guard xmlDocumentCurrentIndexPath.count > 0 else {
            xmlDocument.elements.append(.init(elementName: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict))
            xmlDocumentCurrentIndexPath.append(xmlDocument.elements.endIndex - 1)
            return
        }

        xmlDocument[xmlDocumentCurrentIndexPath]?.childeren.append(.init(elementName: elementName, namespaceURI: namespaceURI, qualifiedName: qName, attributes: attributeDict))
        xmlDocumentCurrentIndexPath.append((xmlDocument[xmlDocumentCurrentIndexPath]?.childeren.endIndex ?? 1) - 1)
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        isNodeOpend = false

        var parentElementIndexPath = xmlDocumentCurrentIndexPath
        repeat {
            guard xmlDocument[xmlDocumentCurrentIndexPath]?.elementName == elementName else {
                parentElementIndexPath.removeLast()
                continue
            }

            xmlDocumentCurrentIndexPath.removeLast(xmlDocumentCurrentIndexPath.count - parentElementIndexPath.count + 1)
            break
        } while (parentElementIndexPath.count > 0)
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentNode = xmlDocument[xmlDocumentCurrentIndexPath], isNodeOpend else {
            return
        }

        xmlDocument[xmlDocumentCurrentIndexPath]?.character = [currentNode.character, string].compactMap({$0}).joined()
    }
}

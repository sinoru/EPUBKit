//
//  XMLElement.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation

public struct XMLElement {
    var elementName: String
    var namespaceURI: String?
    var qualifiedName: String?
    var attributes: [String: String]

    var character: String?

    var childeren: [Self] = []
}

extension XMLElement {
    subscript(indexPath: IndexPath) -> Self? {
        get {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                return self
            }

            guard index < childeren.count else {
                return nil
            }

            if indexPath.count > 0 {
                return self.childeren[index][indexPath]
            } else {
                return self.childeren[index]
            }
        }
        set {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                if let newValue = newValue {
                    self = newValue
                } else {
                    fatalError()
                }
                return
            }

            if indexPath.count > 0 {
                self.childeren[index][indexPath] = newValue
            } else {
                if let newValue = newValue {
                    if index == childeren.count {
                        childeren.append(newValue)
                    } else {
                        childeren[index] = newValue
                    }
                } else {
                    childeren.remove(at: index)
                }
            }
        }
    }
}

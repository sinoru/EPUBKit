//
//  XMLElement.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation

public struct XMLElement {
    public var elementName: String
    public var namespaceURI: String?
    public var qualifiedName: String?
    public var attributes: [String: String]

    public var character: String?

    public var childeren: [Self] = []
}

extension XMLElement {
    public subscript(indexPath: IndexPath) -> Self? {
        get {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                return self
            }

            guard index < childeren.count else {
                return nil
            }

            if !indexPath.isEmpty {
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

            if !indexPath.isEmpty {
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

extension XMLElement {
    public subscript(elementNames: String...) -> XMLElement? {
        self[elementNames]
    }

    public subscript(elementNames: [String]) -> XMLElement? {
        return self.childeren.first(where: { $0.elementName == elementNames.first }).flatMap {
            if elementNames.count > 1 {
                return $0[Array(elementNames.dropFirst())]
            } else {
                return $0
            }
        }
    }
}

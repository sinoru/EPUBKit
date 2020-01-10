//
//  XMLDocument.swift
//  
//
//  Created by Jaehong Kang on 2020/01/10.
//

import Foundation

public struct XMLDocument {
    var elements: [XMLElement] = []
}

extension XMLDocument {
    subscript(indexPath: IndexPath) -> XMLElement? {
        get {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                fatalError()
            }

            guard index < elements.count else {
                return nil
            }

            if indexPath.count > 0 {
                return self.elements[index][indexPath]
            } else {
                return self.elements[index]
            }
        }
        set {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                fatalError()
            }

            if indexPath.count > 0 {
                self.elements[index][indexPath] = newValue
            } else {
                if let newValue = newValue {
                    if index == elements.count {
                        elements.append(newValue)
                    } else {
                        elements[index] = newValue
                    }
                } else {
                    elements.remove(at: index)
                }
            }
        }
    }

    subscript(indexes: [Int]) -> XMLElement? {
        get {
            return self[IndexPath(indexes: indexes)]
        }
        set {
            self[IndexPath(indexes: indexes)] = newValue
        }
    }
}

extension XMLDocument {
    subscript(elementNames: String...) -> XMLElement? {
        self[elementNames]
    }

    subscript(elementNames: [String]) -> XMLElement? {
        return self.elements.first(where: { $0.elementName == elementNames.first }).flatMap {
            if elementNames.count > 1 {
                return $0[Array(elementNames.dropFirst())]
            } else {
                return $0
            }
        }
    }
}

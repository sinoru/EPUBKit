//
//  XMLDocument.swift
//  XMLKit
//

import Foundation

public struct XMLDocument {
    public var elements: [XMLElement] = []
}

extension XMLDocument {
    public subscript(indexPath: IndexPath) -> XMLElement? {
        get {
            var indexPath = indexPath

            guard let index = indexPath.popFirst() else {
                fatalError()
            }

            guard index < elements.count else {
                return nil
            }

            if !indexPath.isEmpty {
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

            if !indexPath.isEmpty {
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

    public subscript(indexes: [Int]) -> XMLElement? {
        get {
            return self[IndexPath(indexes: indexes)]
        }
        set {
            self[IndexPath(indexes: indexes)] = newValue
        }
    }
}

extension XMLDocument {
    public subscript(elementNames: String...) -> XMLElement? {
        self[elementNames]
    }

    public subscript(elementNames: [String]) -> XMLElement? {
        return self.elements.first(where: { $0.elementName == elementNames.first }).flatMap {
            if elementNames.count > 1 {
                return $0[Array(elementNames.dropFirst())]
            } else {
                return $0
            }
        }
    }
}

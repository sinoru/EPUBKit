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
}

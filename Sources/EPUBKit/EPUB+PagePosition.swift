//
//  EPUB+PagePosition.swift
//  
//
//  Created by Jaehong Kang on 2020/01/21.
//

#if canImport(CoreGraphics)
import Foundation
import CoreGraphics

extension EPUB {
    public struct PagePosition: Equatable {
        public weak var coordinator: EPUB.PageCoordinator?
        public var itemRef: EPUB.Item.Ref

        public var contentYOffset: CGFloat
        public var contentSize: CGSize

        public var pageSize: CGSize
    }
}

extension EPUB.PagePosition: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(coordinator.flatMap { ObjectIdentifier($0) })
        hasher.combine(itemRef)
        hasher.combine(contentYOffset)
    }
}

extension Array where Element == EPUB.PagePosition {
    public func estimatedIndex(of element: Element) -> Int? {
        return lastIndex {
            guard
                $0.coordinator === element.coordinator,
                $0.itemRef == element.itemRef
            else {
                return false
            }

            return $0.contentYOffset <= element.contentYOffset
        }
    }
}

#endif

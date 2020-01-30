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
        public var itemRef: EPUB.Item.Ref

        public var contentInfo: ContentInfo
        public var contentYOffset: CGFloat

        public var pageSize: CGSize
    }
}

extension EPUB.PagePosition {
    public struct ContentInfo: Equatable, Hashable {
        public var contentSize: CGSize
        public var contentYOffsetsByID: [String: CGFloat]
    }
}

extension EPUB.PagePosition: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(itemRef)
        hasher.combine(contentYOffset)
    }
}

extension Array where Element == EPUB.PagePosition {
    public func estimatedIndex(of element: Element) -> Int? {
        return lastIndex {
            guard
                $0.pageSize == element.pageSize,
                $0.itemRef == element.itemRef
            else {
                return false
            }

            return $0.contentYOffset <= element.contentYOffset
        }
    }

    subscript(itemRef: EPUB.Item.Ref, contentYOffset: CGFloat) -> Element? {
        return last {
            guard
                $0.itemRef == itemRef
            else {
                return false
            }

            return $0.contentYOffset <= contentYOffset
        }
    }
}

extension Array where Element == EPUB.PagePosition? {
    public func estimatedIndex(of element: EPUB.PagePosition) -> Int? {
        return lastIndex {
            guard
                $0?.pageSize == element.pageSize,
                $0?.itemRef == element.itemRef
            else {
                return false
            }

            return ($0?.contentYOffset ?? 0) <= element.contentYOffset
        }
    }

    subscript(itemRef: EPUB.Item.Ref, contentYOffset: CGFloat) -> Element? {
        return last {
            guard
                $0?.itemRef == itemRef
            else {
                return false
            }

            return ($0?.contentYOffset ?? 0) <= contentYOffset
        }
    }
}

extension Array where Element == [EPUB.PagePosition]? {
    public func flatten() -> [EPUB.PagePosition?] {
        self.reduce(into: [], { $0 += $1 ?? [nil] })
    }
}

#endif

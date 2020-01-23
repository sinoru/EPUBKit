//
//  EPUB+PageCoordinatorManager.swift
//  
//
//  Created by Jaehong Kang on 2020/01/21.
//

#if canImport(CoreGraphics) && canImport(WebKit)

import Foundation
import CoreGraphics

extension EPUB {
    class PageCoordinatorManager {
        unowned let epub: EPUB

        @Published var itemContentInfoResultsByWidth = [CGFloat: [Item.Ref: Result<ItemContentInfo, Swift.Error>]]()
        @Published var pagePositionsBySize = [CGSize: Result<[PagePosition], Swift.Error>]()

        init(_ epub: EPUB) {
            self.epub = epub
        }

        func newPageCoordinator() -> PageCoordinator {
            return .init(self)
        }

        subscript(pageWidth pageWidth: CGFloat) -> [Item.Ref: Result<ItemContentInfo, Swift.Error>] {
            get {
                return itemContentInfoResultsByWidth[pageWidth] ?? [:]
            }
            set {
                itemContentInfoResultsByWidth[pageWidth] = newValue
            }
        }
    }
}

#endif

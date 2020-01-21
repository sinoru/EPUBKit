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

        @Published var spineItemHeightCalculateResultsByWidth = [CGFloat: [Item.Ref: Result<CGFloat, Swift.Error>]]()
        @Published var pagePositionsBySize = [CGSize: Result<[PagePosition], Swift.Error>]()

        init(_ epub: EPUB) {
            self.epub = epub
        }

        func newPageCoordinator() -> PageCoordinator {
            return .init(self)
        }

        subscript(pageWidth pageWidth: CGFloat) -> [Item.Ref: Result<CGFloat, Swift.Error>] {
            get {
                return spineItemHeightCalculateResultsByWidth[pageWidth] ?? [:]
            }
            set {
                spineItemHeightCalculateResultsByWidth[pageWidth] = newValue
            }
        }
    }
}

#endif

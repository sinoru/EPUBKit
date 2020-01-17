//
//  EPUB+PageCoordinator.swift
//  
//
//  Created by Jaehong Kang on 2020/01/16.
//

import Foundation
import Combine

#if canImport(CoreGraphics) && canImport(WebKit)
import CoreGraphics
import WebKit

extension EPUB {
    open class PageCoordinator: ObservableObject {
        private weak var epub: EPUB?
        private lazy var offscreenPrerenderOperationQueue: OperationQueue = {
            let offscreenPrerenderOperationQueue = OperationQueue()

            offscreenPrerenderOperationQueue.underlyingQueue = DispatchQueue.main // Operation contains UIView which should be called on main thread even dealloc
            offscreenPrerenderOperationQueue.maxConcurrentOperationCount = 1

            return offscreenPrerenderOperationQueue
        }()

        public var pageWidth: CGFloat = 0.0 {
            didSet {
                spineItemHeights = spineItemHeightsByWidth[self.pageWidth] ?? [:]
                spineItemHeightsSubscriber = $spineItemHeights
                    .receive(on: epub?.mainQueue ?? DispatchQueue.main)
                    .sink { [pageWidth = self.pageWidth](spineItemHeights) in
                        self.spineItemHeightsByWidth[pageWidth] = spineItemHeights
                    }
                calculateSpineItemHeights()
            }
        }

        private var spineItemHeightsByWidth = [CGFloat: [Item.Ref: Result<CGFloat, Swift.Error>]]()
        @Published public var spineItemHeights = [Item.Ref: Result<CGFloat, Swift.Error>]()
        lazy private var spineItemHeightsSubscriber = $spineItemHeights
            .receive(on: epub?.mainQueue ?? DispatchQueue.main)
            .sink { [pageWidth = self.pageWidth](spineItemHeights) in
                self.spineItemHeightsByWidth[pageWidth] = spineItemHeights
            }

        init(_ epub: EPUB) {
            self.epub = epub
            _ = spineItemHeightsSubscriber
        }


    }
}

extension EPUB.PageCoordinator {
    func calculateSpineItemHeights() {
        guard
            let epub = epub,
            let resourceURL = epub.resourceURL,
            let spine = epub.spine,
            let items = epub.items
        else {
            return
        }

        guard pageWidth > 0 else {
            return
        }

        spine.itemRefs.forEach { (itemRef) in
            guard let item = items[itemRef] else {
                return
            }

            let operation = OffscreenPrerenderOperation(
                request: .fileURL(resourceURL.appendingPathComponent(item.relativePath), allowingReadAccessTo: resourceURL),
                pageWidth: self.pageWidth
            )
            operation.completionBlock = { [weak operation]() in
                guard case .finished(let result) = operation?.state else {
                    return
                }

                self.spineItemHeights[itemRef] = result
            }

            offscreenPrerenderOperationQueue.addOperation(operation)
        }
    }
}

#endif

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
        private lazy var queue: OperationQueue = {
            let queue = OperationQueue()

            queue.underlyingQueue = epub?.mainQueue
            queue.maxConcurrentOperationCount = 3

            return queue
        }()

        public var pageWidth: CGFloat = 0.0 {
            didSet {
                spineItemHeights = spineItemHeightByWidth[self.pageWidth] ?? [:]
                spineItemHeightsSubscriber = $spineItemHeights
                    .receive(on: epub?.mainQueue ?? DispatchQueue.main)
                    .sink { [pageWidth = self.pageWidth](spineItemHeights) in
                        self.spineItemHeightByWidth[pageWidth] = spineItemHeights
                    }
                calculate()
            }
        }

        private var spineItemHeightByWidth = [CGFloat: [Item.Ref: CGFloat]]()

        @Published public var spineItemHeights = [Item.Ref: CGFloat]()
        lazy private var spineItemHeightsSubscriber = $spineItemHeights
            .receive(on: epub?.mainQueue ?? DispatchQueue.main)
            .sink { [pageWidth = self.pageWidth](spineItemHeights) in
                self.spineItemHeightByWidth[pageWidth] = spineItemHeights
            }

        init(_ epub: EPUB) {
            self.epub = epub
            _ = spineItemHeightsSubscriber
        }

        func calculate() {
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
                    if case .finished(.success(let height)) = operation?.state {
                        self.spineItemHeights[itemRef] = height
                    } else {
                        debugPrint(operation?.state)
                    }
                }

                queue.addOperation(operation)
            }
        }
    }
}
#endif

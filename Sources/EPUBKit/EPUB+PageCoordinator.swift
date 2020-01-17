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

        open var pageSize: CGSize = .zero {
            didSet {
                if pageSize.width != oldValue.width {
                    spineItemHeightCalculateResultsByWidth[pageSize.width] = [:]
                    calculateSpineItemHeights()
                }
            }
        }

        @Published private var spineItemHeightCalculateResultsByWidth = [CGFloat: [Item.Ref: Result<CGFloat, Swift.Error>]]()

        open func spineItemHeightForRef(_ itemRef: Item.Ref) throws -> CGFloat? {
            try spineItemHeightCalculateResultsByWidth[pageSize.width]?[itemRef]?.get()
        }

        open func spineItemHeightPublisherForRef(_ itemRef: Item.Ref) -> AnyPublisher<CGFloat, Swift.Error> {
            return AnyPublisher(
                $spineItemHeightCalculateResultsByWidth
                    .compactMap({ $0[self.pageSize.width] })
                    .compactMap({ $0[itemRef] })
                    .tryMap({ try $0.get() })
                    .removeDuplicates()
            )
        }

        init(_ epub: EPUB) {
            self.epub = epub
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

        guard pageSize.width > 0 else {
            return
        }

        spine.itemRefs.forEach { (itemRef) in
            guard let item = items[itemRef] else {
                return
            }

            let operation = OffscreenPrerenderOperation(
                request: .fileURL(resourceURL.appendingPathComponent(item.relativePath), allowingReadAccessTo: resourceURL),
                pageWidth: self.pageSize.width
            )
            operation.completionBlock = { [weak operation]() in
                guard let operation = operation else {
                    return
                }

                guard case .finished(let result) = operation.state else {
                    return
                }

                self.spineItemHeightCalculateResultsByWidth[operation.pageWidth]?[itemRef] = result
            }

            offscreenPrerenderOperationQueue.addOperation(operation)
        }
    }
}

extension EPUB.PageCoordinator: Identifiable { }

extension EPUB.PageCoordinator: Equatable {
    public static func == (lhs: EPUB.PageCoordinator, rhs: EPUB.PageCoordinator) -> Bool {
        lhs.id == rhs.id
    }
}

extension EPUB.PageCoordinator {
    struct Position: Equatable {
        weak var coordinator: EPUB.PageCoordinator?
        var epubItemRef: EPUB.Item.Ref?
        var yOffset: CGFloat = 0
    }
}

#endif

//
//  EPUB+PageCoordinator.swift
//  
//
//  Created by Jaehong Kang on 2020/01/16.
//

import Foundation
import Combine
import Shinjuku

#if canImport(CoreGraphics) && canImport(WebKit)
import CoreGraphics
import WebKit

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}

extension EPUB {
    open class PageCoordinator: ObservableObject {
        open private(set) weak var epub: EPUB?
        private lazy var offscreenPrerenderOperationQueue: OperationQueue = {
            let offscreenPrerenderOperationQueue = OperationQueue()

            offscreenPrerenderOperationQueue.underlyingQueue = DispatchQueue.main // Operation contains UIView which should be called on main thread even dealloc
            offscreenPrerenderOperationQueue.maxConcurrentOperationCount = 1

            return offscreenPrerenderOperationQueue
        }()

        open var pageSize: CGSize = .zero {
            didSet {
                if pageSize.width != oldValue.width {
                    DispatchQueue.main.safeSync { self.spineItemHeightCalculateResultsByWidth[self.pageSize.width] = [:] }
                    self.calculateSpineItemHeights()
                }
            }
        }

        @Published private var spineItemHeightCalculateResultsByWidth = [CGFloat: [Item.Ref: Result<CGFloat, Swift.Error>]]() {
            didSet {
                self.calculatePagePositions()
            }
        }
        @Published private var pagePositionsBySize = [CGSize: Result<[PagePosition], Swift.Error>]()

        open var pagePositions: Result<[PagePosition], Swift.Error> {
            return pagePositionsBySize[pageSize] ?? .success([])
        }

        open var pagePositionsPublisher: AnyPublisher<[PagePosition], Swift.Error> {
            return $pagePositionsBySize
                .compactMap({ $0[self.pageSize] })
                .tryMap({ try $0.get() })
                .removeDuplicates()
                .eraseToAnyPublisher()
        }

        init(_ epub: EPUB) {
            self.epub = epub
        }

        open func spineItemHeightForRef(_ itemRef: Item.Ref) throws -> CGFloat? {
            try spineItemHeightCalculateResultsByWidth[pageSize.width]?[itemRef]?.get()
        }

        open func spineItemHeightPublisherForRef(_ itemRef: Item.Ref) -> AnyPublisher<CGFloat, Swift.Error> {
            return $spineItemHeightCalculateResultsByWidth
                .compactMap({ $0[self.pageSize.width] })
                .compactMap({ $0[itemRef] })
                .tryMap({ try $0.get() })
                .removeDuplicates()
                .eraseToAnyPublisher()
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

        epub.mainQueue.async {
            let pageSize = self.pageSize

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

                    DispatchQueue.main.safeSync { self.spineItemHeightCalculateResultsByWidth[operation.pageWidth]?[itemRef] = result }
                }

                self.offscreenPrerenderOperationQueue.addOperation(operation)
            }
        }
    }

    func calculatePagePositions() {
        guard
            let epub = epub
        else {
            return
        }

        epub.mainQueue.async {
            guard let spine = epub.spine else {
                return
            }

            let pageSize = self.pageSize

            let pagePositionsResult: Result<[PagePosition], Swift.Error> = {
                do {
                    return .success(try spine.itemRefs.flatMap { (itemRef) -> [PagePosition] in
                        guard let spineItemHeightResult = self.spineItemHeightCalculateResultsByWidth[pageSize.width]?[itemRef] else {
                            return []
                        }

                        let spineItemHeight = try spineItemHeightResult.get()

                        return (0..<Int(ceil(spineItemHeight / pageSize.height))).map {
                            return PagePosition(
                                coordinator: self,
                                epubItemRef: itemRef,
                                yOffset: CGFloat($0) * pageSize.height
                            )
                        }

                    })
                } catch {
                    return .failure(error)
                }
            }()

            DispatchQueue.main.async {
                self.pagePositionsBySize[pageSize] = pagePositionsResult
            }
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
    public struct PagePosition: Equatable {
        public weak var coordinator: EPUB.PageCoordinator?
        public var epubItemRef: EPUB.Item.Ref
        public var yOffset: CGFloat
    }
}

extension Array where Element == EPUB.PageCoordinator.PagePosition {
    public func estimatedIndex(of element: Element) -> Int? {
        return lastIndex {
            guard
                $0.coordinator === element.coordinator,
                $0.epubItemRef == element.epubItemRef
            else {
                return false
            }

            return $0.yOffset <= element.yOffset
        }
    }
}

#endif

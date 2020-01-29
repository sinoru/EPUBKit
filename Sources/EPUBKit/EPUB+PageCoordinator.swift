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
        private unowned var pageCoordinatorManager: PageCoordinatorManager

        lazy var offscreenPrerenderOperationQueue: OperationQueue = {
            let offscreenPrerenderOperationQueue = OperationQueue()

            offscreenPrerenderOperationQueue.underlyingQueue = mainQueue
            offscreenPrerenderOperationQueue.maxConcurrentOperationCount = 1

            return offscreenPrerenderOperationQueue
        }()

        open var epub: EPUB {
            return pageCoordinatorManager.epub
        }

        @Published open var pageSize: CGSize = .zero {
            didSet {
                if pageSize.width != oldValue.width {
                    calculateSpineItemHeights()
                }
            }
        }

        open var pagePositions: Result<[PagePosition], Swift.Error> {
            pageCoordinatorManager.pagePositionsBySize[pageSize] ?? .success([])
        }

        open var pagePositionsPublisher: AnyPublisher<[PagePosition], Swift.Error> {
            pageCoordinatorManager.$pagePositionsBySize
                .receive(on: mainQueue)
                .compactMap { $0[self.pageSize] }
                .tryMap { try $0.get() }
                .eraseToAnyPublisher()
        }

        open var itemContentInfoResults: [Item.Ref: Result<ItemContentInfo, Swift.Error>] {
            pageCoordinatorManager.itemContentInfoResultsByWidth[pageSize.width] ?? [:]
        }

        open var itemContentInfoResultsPublisher: AnyPublisher<[Item.Ref: Result<ItemContentInfo, Swift.Error>], Never> {
            pageCoordinatorManager.$itemContentInfoResultsByWidth
                .receive(on: mainQueue)
                .compactMap { $0[self.pageSize.width] }
                .eraseToAnyPublisher()
        }

        open var progress: Progress {
            offscreenPrerenderOperationQueue.progress
        }

        private var itemContentInfoResultsSubscription: AnyCancellable?
        private var spineItemHeightCalculateResultsByWidthSubscriber: AnyCancellable?
        private var epubStateSubscriber: AnyCancellable?

        lazy var mainQueue = DispatchQueue(
            label: "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).main", target: epub.mainQueue
        )

        init(_ pageCoordinatorManager: PageCoordinatorManager) {
            self.pageCoordinatorManager = pageCoordinatorManager
            self.itemContentInfoResultsSubscription = pageCoordinatorManager.$itemContentInfoResultsByWidth
                .receive(on: mainQueue)
                .compactMap { [unowned self] in $0[self.pageSize.width] }
                .sink(receiveValue: { [unowned self](_) in
                    self.calculatePagePositions()
                })
            self.epubStateSubscriber = pageCoordinatorManager.epub.$state
                .receive(on: mainQueue)
                .sink(receiveValue: { [unowned self](state) in
                    switch state {
                    case .normal:
                        self.calculateSpineItemHeights()
                    default:
                        break
                    }
                })
        }

        deinit {
            offscreenPrerenderOperationQueue.cancelAllOperations()
        }

        open func itemContentInfoForRef(_ itemRef: Item.Ref) throws -> ItemContentInfo? {
            try itemContentInfoResults[itemRef]?.get()
        }
    }
}

extension EPUB.PageCoordinator {
    func calculateSpineItemHeights() {
        let epub = self.epub

        guard
            let resourceURL = epub.resourceURL
        else {
            return
        }

        let pageSize = self.pageSize
        guard pageSize.width > 0 else {
            return
        }

        mainQueue.async { [weak self, pageCoordinatorManager = self.pageCoordinatorManager] in
            DispatchQueue.main.async { // For cancel operation in Main Thread
                self?.offscreenPrerenderOperationQueue.cancelAllOperations()
            }

            epub.spine.itemRefs.forEach { (itemRef) in
                guard let item = epub.items[itemRef] else {
                    return
                }

                guard pageCoordinatorManager[pageWidth: pageSize.width][itemRef] == nil else {
                    return
                }

                let operation = OffscreenPrerenderOperation(
                    request: .fileURL(resourceURL.appendingPathComponent(item.url.relativePath), allowingReadAccessTo: resourceURL),
                    pageWidth: pageSize.width
                )
                operation.completionBlock = {
                    DispatchQueue.main.async { // For dealloc operation in Main Thread
                        guard case .finished(let result) = operation.state else {
                            return
                        }

                        pageCoordinatorManager[pageWidth: operation.pageWidth][itemRef] = result
                    }
                }

                DispatchQueue.main.async {
                    self?.offscreenPrerenderOperationQueue.progress.totalUnitCount += 1
                    self?.offscreenPrerenderOperationQueue.addOperation(operation)
                }
            }
        }
    }

    func calculatePagePositions() {
        let epub = self.epub
        let pageSize = self.pageSize

        mainQueue.async { [pageCoordinatorManager = self.pageCoordinatorManager] in
            let pagePositionsResult: Result<[EPUB.PagePosition], Swift.Error> = {
                do {
                    return .success(
                        try epub.spine.itemRefs.flatMap { (itemRef) -> [EPUB.PagePosition] in
                            guard let itemContentInfoResult = pageCoordinatorManager.itemContentInfoResultsByWidth[pageSize.width]?[itemRef] else {
                                return []
                            }

                            let itemContentInfo = try itemContentInfoResult.get()

                            return (0..<Int(ceil(itemContentInfo.contentSize.height / pageSize.height))).map {
                                let pageContentYOffset = CGFloat($0) * pageSize.height
                                let pageSize = CGSize(width: pageSize.width, height: min(pageSize.height, itemContentInfo.contentSize.height - pageContentYOffset))

                                let pageContentYOffsetsByID = itemContentInfo.contentYOffsetsByID.filter({ (pageContentYOffset...(pageContentYOffset + pageSize.height)) ~= $0.value })

                                return EPUB.PagePosition(
                                    itemRef: itemRef,
                                    contentInfo: .init(contentSize: itemContentInfo.contentSize, contentYOffsetsByID: pageContentYOffsetsByID),
                                    contentYOffset: pageContentYOffset,
                                    pageSize: pageSize
                                )
                            }
                        }
                    )
                } catch {
                    return .failure(error)
                }
            }()

            DispatchQueue.main.async {
                pageCoordinatorManager.pagePositionsBySize[pageSize] = pagePositionsResult
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

#endif

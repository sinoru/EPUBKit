//
//  EPUB+PageCoordinator.swift
//  
//
//  Created by Jaehong Kang on 2020/01/16.
//

import Combine
import Foundation
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

        open var pagePositions: [[PagePosition]?] {
            return epub.spine.itemRefs
                .map {
                    pageCoordinatorManager[pageSize: pageSize][$0]
                }
        }
        
        open var pagePositionsPublisher: AnyPublisher<[[PagePosition]?], Never> {
            pageCoordinatorManager.$pagePositionsBySize
                .receive(on: mainQueue)
                .compactMap { $0[self.pageSize] }
                .map { pagePositions in self.epub.spine.itemRefs.map { pagePositions[$0] } }
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

        @Published open private(set) var progress = Progress()

        private var spineItemHeightCalculateResultsByWidthSubscriber: AnyCancellable?
        private var epubStateSubscriber: AnyCancellable?

        lazy var mainQueue = DispatchQueue(
            label: "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).main",
            target: epub.mainQueue
        )

        lazy var offscreenPrerenderOperationQueue: OperationQueue = {
            let offscreenPrerenderOperationQueue = OperationQueue()

            offscreenPrerenderOperationQueue.name = "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).offscreenPrerender"
            offscreenPrerenderOperationQueue.underlyingQueue = mainQueue
            offscreenPrerenderOperationQueue.maxConcurrentOperationCount = ProcessInfo.processInfo.processorCount

            return offscreenPrerenderOperationQueue
        }()

        init(_ pageCoordinatorManager: PageCoordinatorManager) {
            self.pageCoordinatorManager = pageCoordinatorManager
            self.epubStateSubscriber = pageCoordinatorManager.epub.$state
                .subscribe(on: mainQueue)
                .receive(on: mainQueue)
                .sink(receiveValue: { [unowned self] state in
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
            self?.offscreenPrerenderOperationQueue.cancelAllOperations()
            DispatchQueue.main.async {
                self?.progress = Progress(totalUnitCount: Int64(epub.spine.itemRefs.count))
            }

            epub.spine.itemRefs.forEach { itemRef in
                guard let item = epub.items[itemRef] else {
                    return
                }

                guard pageCoordinatorManager[pageWidth: pageSize.width][itemRef] == nil else {
                    self?.calculatePagePositions(for: itemRef)
                    return
                }

                let operation = OffscreenPrerenderOperation(
                    request: .fileURL(
                        resourceURL.appendingPathComponent(item.url.relativePath),
                        allowingReadAccessTo: resourceURL
                    ),
                    pageWidth: pageSize.width
                )
                operation.completionBlock = {
                    guard case .finished(let result) = operation.state else {
                        return
                    }

                    DispatchQueue.main.async {
                        self?.progress.completedUnitCount += 1
                        pageCoordinatorManager[pageWidth: operation.pageWidth][itemRef] = result
                        self?.calculatePagePositions(for: itemRef)
                    }
                }

                self?.offscreenPrerenderOperationQueue.addOperation(operation)
            }
        }
    }

    func calculatePagePositions(for itemRef: EPUB.Item.Ref) {
        let pageSize = self.pageSize

        mainQueue.async { [pageCoordinatorManager = self.pageCoordinatorManager] in
            guard pageCoordinatorManager[pageSize: pageSize][itemRef] == nil else {
                return
            }

            guard let itemContentInfoResult = pageCoordinatorManager.itemContentInfoResultsByWidth[pageSize.width]?[itemRef] else {
                return
            }

            guard let itemContentInfo = try? itemContentInfoResult.get() else {
                return
            }

            let pagePositions: [EPUB.PagePosition] = (0..<Int(ceil(itemContentInfo.contentSize.height / pageSize.height))).map {
                let pageContentYOffset = CGFloat($0) * pageSize.height
                let pageSize = CGSize(
                    width: pageSize.width,
                    height: min(pageSize.height, itemContentInfo.contentSize.height - pageContentYOffset)
                )

                let pageContentYOffsetsByID = itemContentInfo.contentYOffsetsByID
                    .filter({ (pageContentYOffset...(pageContentYOffset + pageSize.height)) ~= $0.value })

                return EPUB.PagePosition(
                    itemRef: itemRef,
                    contentInfo: .init(
                        contentSize: itemContentInfo.contentSize,
                        contentYOffsetsByID: pageContentYOffsetsByID
                    ),
                    contentYOffset: pageContentYOffset,
                    pageSize: pageSize
                )
            }

            DispatchQueue.main.async {
                pageCoordinatorManager[pageSize: pageSize][itemRef] = pagePositions
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

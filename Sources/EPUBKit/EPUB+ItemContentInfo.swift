//
//  EPUB+ItemContentInfo.swift
//  EPUBKit
//

#if canImport(CoreGraphics)
import CoreGraphics

extension EPUB {
    public struct ItemContentInfo: Equatable, Hashable {
        public var contentSize: CGSize
        public var contentYOffsetsByID: [String: CGFloat]
    }
}
#endif

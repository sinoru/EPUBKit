//
//  EPUB+ItemContentInfo.swift
//  
//
//  Created by Jaehong Kang on 2020/01/23.
//

#if canImport(CoreGraphics)
import CoreGraphics

extension EPUB {
    public struct ItemContentInfo: Equatable, Hashable {
        var contentSize: CGSize
        var contentYOffsetsByID: [String: CGFloat]
    }
}
#endif

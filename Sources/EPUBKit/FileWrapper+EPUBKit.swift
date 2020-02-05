//
//  FileWrapper+EPUBKit.swift
//  EPUBKit
//

import Foundation

extension FileWrapper {
    subscript(path: String) -> FileWrapper? {
        return path
            .split(separator: "/")
            .reduce(self as FileWrapper?, { (result: FileWrapper?, filename: Substring) in
                result?.fileWrappers?[String(filename)]
            })
    }
}

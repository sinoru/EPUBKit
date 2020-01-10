//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation
import XMLKit

let metaInfContainerFilename = "META-INF/container.xml"

open class EPUB {
    public let fileURL: URL
    public let fileWrapper: FileWrapper
    public private(set) var state: State = .preflight

    public init(fileURL url: URL) throws {
        self.fileURL = url
        self.fileWrapper = try FileWrapper(url: url)

        debugPrint(self.fileURL)

        try initializeEPUB()
    }

    func initializeEPUB() throws {
        if fileWrapper.isDirectory {
            try initializeEPUBDirectory()
        } else {
            try initializeEPUBFile()
        }
    }

    func initializeEPUBFile() throws {
        let zip = try ZIP(fileURL: self.fileURL)

        debugPrint(zip)

        zip.loadFile(filename: metaInfContainerFilename) { (result) in
            switch result {
            case .success(let item):
                let operation = XMLParseOperation(data: item.data)
                operation.start()

                debugPrint(operation.xmlDocument)
            case .failure(let error):
                self.state = .error(error)
            }
        }
    }

    func initializeEPUBDirectory() throws {

    }
}

extension EPUB {
    public enum State {
        case preflight
        case closed
        case normal
        case error(Swift.Error)
    }
}

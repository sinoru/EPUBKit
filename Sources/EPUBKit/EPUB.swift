//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation
import Combine
import XMLKit

let metaInfContainerFilename = "META-INF/container.xml"

open class EPUB: ObservableObject {
    public let fileURL: URL
    public let fileWrapper: FileWrapper
    @Published public private(set) var state: State = .preflight

    public private(set) var metadata: Metadata?

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
            case .success(let metaInfItem):
                DispatchQueue.global().async {
                    let operation = XMLParseOperation(data: metaInfItem.data)
                    operation.start()

                    guard let rootfile = operation.xmlDocument["container", "rootfiles", "rootfile"] else {
                        self.state = .error(Error.invalidEPUB)
                        return
                    }

                    guard let opfPath = rootfile.attributes["full-path"] else {
                        self.state = .error(Error.invalidEPUB)
                        return
                    }

                    zip.loadFile(filename: opfPath) { (result) in
                        switch result {
                        case .success(let opfItem):
                            DispatchQueue.global().async {
                                let operation = XMLParseOperation(data: opfItem.data)
                                operation.start()

                                guard let metadata = operation.xmlDocument["package", "metadata"] else {
                                    self.state = .error(Error.invalidEPUB)
                                    return
                                }

                                self.metadata = .init(
                                    title: metadata["dc:title"]?.character,
                                    creator: metadata["dc:creator"]?.character
                                )

                                self.state = .normal
                            }
                        case .failure(let error):
                            self.state = .error(error)
                        }
                    }
                }
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

extension EPUB {
    public enum Error: Swift.Error {
        case invalidEPUB
    }
}

extension EPUB {
    public struct Metadata {
        public var title: String?
        public var creator: String?
    }
}

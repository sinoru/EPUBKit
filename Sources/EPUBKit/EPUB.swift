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

    private lazy var mainQueue = DispatchQueue(label: "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).main")

    public init(fileURL url: URL) throws {
        self.fileURL = url
        self.fileWrapper = try FileWrapper(url: url)

        debugPrint(self.fileURL)

        try initializeEPUB()
    }

    private func initializeEPUB() throws {
        if fileWrapper.isDirectory {
            try initializeEPUBDirectory()
        } else {
            try initializeEPUBFile()
        }
    }

    private func initializeEPUBFile() throws {
        let zip = try ZIP(fileURL: self.fileURL)

        zip.loadFile(filename: metaInfContainerFilename) { (result) in
            switch result {
            case .success(let metaInfItem):
                self.mainQueue.async {
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
                            self.mainQueue.async {
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

    private func initializeEPUBDirectory() throws {
        guard
            let mainInfFileWrapper = fileWrapper[metaInfContainerFilename],
            let mainInfData = mainInfFileWrapper.regularFileContents
        else {
            self.state = .error(Error.invalidEPUB)
            return
        }

        mainQueue.async {
            let operation = XMLParseOperation(data: mainInfData)
            operation.start()

            guard let rootfile = operation.xmlDocument["container", "rootfiles", "rootfile"] else {
                self.state = .error(Error.invalidEPUB)
                return
            }

            guard let opfPath = rootfile.attributes["full-path"] else {
                self.state = .error(Error.invalidEPUB)
                return
            }

            guard
                let opfFileWrapper = self.fileWrapper[opfPath],
                let opfData = opfFileWrapper.regularFileContents
            else {
                self.state = .error(Error.invalidEPUB)
                return
            }

            self.mainQueue.async {
                let operation = XMLParseOperation(data: opfData)
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
        }

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

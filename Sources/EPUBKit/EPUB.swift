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
    private lazy var temporaryDirectoryFileURL: URL = {
        var fileURL = URL(fileURLWithPath: NSTemporaryDirectory())

        Bundle(for: Self.self).bundleIdentifier.flatMap {
            fileURL.appendPathComponent($0)
        }
        fileURL.appendPathComponent(String(reflecting: Self.self))
        fileURL.appendPathComponent(UUID().uuidString)

        return fileURL
    }()

    public let epubFileURL: URL

    private let epubFileWrapper: FileWrapper

    @Published public private(set) var state: State = .preflight

    public private(set) var resourceURL: URL?

    public private(set) var metadata: Metadata?
    public private(set) var items: [Item]?
    public private(set) var spine: Spine?

    private lazy var mainQueue = DispatchQueue(label: "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).main")

    public init(fileURL url: URL) throws {
        self.epubFileURL = url
        self.epubFileWrapper = try FileWrapper(url: url)

        try initializeEPUB()
    }

    deinit {
        self.close()
    }

    private func initializeEPUB() throws {
        if epubFileWrapper.isDirectory {
            try initializeEPUBDirectory()
        } else {
            try initializeEPUBFile()
        }
    }

    private func initializeEPUBFile() throws {
        mainQueue.async {
            do {
                let zip = try ZIP(fileURL: self.epubFileURL)

                let metaInfItem = try zip.loadFile(filename: metaInfContainerFilename)

                let metaInfParseOperation = XMLParseOperation(data: metaInfItem.data)
                metaInfParseOperation.start()

                guard let metaInfRootfile = metaInfParseOperation.xmlDocument["container", "rootfiles", "rootfile"] else {
                    self.state = .error(Error.invalidEPUB)
                    return
                }

                guard let metaInfOPFPath = metaInfRootfile.attributes["full-path"] else {
                    self.state = .error(Error.invalidEPUB)
                    return
                }

                let opfItem = try zip.loadFile(filename: metaInfOPFPath)

                let opfParseOperation = XMLParseOperation(data: opfItem.data)
                opfParseOperation.start()

                guard let opfMetadata = opfParseOperation.xmlDocument["package", "metadata"] else {
                    self.state = .error(Error.invalidEPUB)
                    return
                }

                self.metadata = .init(metadataXMLElement: opfMetadata)

                guard let opfManifest = opfParseOperation.xmlDocument["package", "manifest"] else {
                    self.state = .error(Error.invalidEPUB)
                    return
                }

                self.items = try Item.items(manifestXMLElement: opfManifest)

                guard let opfSpine = opfParseOperation.xmlDocument["package", "spine"] else {
                    self.state = .error(Error.invalidEPUB)
                    return
                }

                self.spine = try .init(spineXMLElement: opfSpine)

                self.state = .closed
            } catch {
                self.state = .error(error)
            }
        }
    }

    private func initializeEPUBDirectory() throws {
        guard
            let mainInfFileWrapper = epubFileWrapper[metaInfContainerFilename],
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
                let opfFileWrapper = self.epubFileWrapper[opfPath],
                let opfData = opfFileWrapper.regularFileContents
            else {
                self.state = .error(Error.invalidEPUB)
                return
            }

            self.mainQueue.async {
                do {
                    let operation = XMLParseOperation(data: opfData)
                    operation.start()

                    guard let opfMetadata = operation.xmlDocument["package", "metadata"] else {
                        self.state = .error(Error.invalidEPUB)
                        return
                    }

                    self.metadata = .init(metadataXMLElement: opfMetadata)

                    guard let opfManifest = operation.xmlDocument["package", "manifest"] else {
                        self.state = .error(Error.invalidEPUB)
                        return
                    }

                    self.items = try Item.items(manifestXMLElement: opfManifest)

                    guard let opfSpine = operation.xmlDocument["package", "spine"] else {
                        self.state = .error(Error.invalidEPUB)
                        return
                    }

                    self.spine = try .init(spineXMLElement: opfSpine)

                    self.state = .closed
                } catch {
                    self.state = .error(error)
                }
            }
        }
    }

    open func open(completion: ((Result<Void, Swift.Error>) -> Void)? = nil) {
        guard case .closed = state else {
            completion?(.failure(Error.invalidState))
            return
        }

        guard !epubFileWrapper.isDirectory else {
            resourceURL = epubFileURL
            state = .normal
            completion?(.success(()))
            return
        }

        mainQueue.async {
            do {
                let zip = try ZIP(fileURL: self.epubFileURL)

                try zip.unarchiveItems(to: self.temporaryDirectoryFileURL)

                self.resourceURL = self.temporaryDirectoryFileURL
                completion?(.success(()))
            } catch {
                self.state = .error(error)
                completion?(.failure(error))
            }
        }
    }

    open func close(completion: ((Result<Void, Swift.Error>) -> Void)? = nil) {
        guard case .normal = state else {
            completion?(.failure(Error.invalidState))
            return
        }

        guard !epubFileWrapper.isDirectory else {
            resourceURL = nil
            state = .closed
            completion?(.success(()))
            return
        }

        do {
            try FileManager.default.removeItem(at: self.temporaryDirectoryFileURL)
            completion?(.success(()))
        } catch {
            completion?(.failure(error))
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
        case invalidState
    }
}

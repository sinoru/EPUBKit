//
//  File.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation
import Combine
import XMLKit
import SNFoundation

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

    private var opfFilePath: String = ""

    @Published open private(set) var state: State = .preflight

    @Published open private(set) var resourceURL: URL?

    @Published open private(set) var metadata: Metadata?
    @Published open private(set) var items: [Item]?
    @Published open private(set) var spine: Spine?

    #if canImport(CoreGraphics) && canImport(WebKit)
    private lazy var pageCoordinatorManager = PageCoordinatorManager(self)
    open func newPageCoordinator() -> PageCoordinator {
        pageCoordinatorManager.newPageCoordinator()
    }
    #endif

    lazy var mainQueue = DispatchQueue(label: "\(String(reflecting: Self.self)).\(Unmanaged.passUnretained(self).toOpaque()).main")

    public init(fileURL url: URL) throws {
        self.epubFileURL = url
        if #available(OSX 10.7, iOS 8.0, *) {
            _ = self.epubFileURL.startAccessingSecurityScopedResource()
        }
        self.epubFileWrapper = try FileWrapper(url: url)

        initializeEPUB()
    }

    deinit {
        self.close()
        if #available(OSX 10.7, iOS 8.0, *) {
            self.epubFileURL.stopAccessingSecurityScopedResource()
        }
    }

    private func initializeEPUB() {
        mainQueue.async {
            do {
                let fileHandler: FileHandler = try {
                    if self.epubFileWrapper.isDirectory {
                        return .fileWrapper(self.epubFileWrapper)
                    } else {
                        return .zip(try ZIP(fileURL: self.epubFileURL))
                    }
                }()

                guard let metaInfData = try fileHandler.loadFileData(filename: metaInfContainerFilename) else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                let metaInfParseOperation = XMLParseOperation(data: metaInfData)
                metaInfParseOperation.start()

                guard let metaInfRootfile = metaInfParseOperation.xmlDocument["container", "rootfiles", "rootfile"] else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                guard let metaInfOPFPath = metaInfRootfile.attributes["full-path"] else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                self.opfFilePath = metaInfOPFPath

                guard let opfData = try fileHandler.loadFileData(filename: metaInfOPFPath) else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                let opfParseOperation = XMLParseOperation(data: opfData)
                opfParseOperation.start()

                guard let opfMetadata = opfParseOperation.xmlDocument["package", "metadata"] else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                let metadata = Metadata(metadataXMLElement: opfMetadata)
                DispatchQueue.main.async {
                    self.metadata = metadata
                }

                guard let opfManifest = opfParseOperation.xmlDocument["package", "manifest"] else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                let items = try Item.items(manifestXMLElement: opfManifest)
                DispatchQueue.main.async {
                    self.items = items
                }

                guard let opfSpine = opfParseOperation.xmlDocument["package", "spine"] else {
                    self.updateState(.error(Error.invalidEPUB))
                    return
                }

                let spine = try Spine(spineXMLElement: opfSpine)
                DispatchQueue.main.async {
                    self.spine = spine
                }

                self.updateState(.closed)
            } catch {
                self.updateState(.error(error))
            }
        }
    }

    open func open(completion: ((Result<Void, Swift.Error>) -> Void)? = nil) {
        guard case .closed = state else {
            completion?(.failure(Error.invalidState))
            return
        }

        guard !epubFileWrapper.isDirectory else {
            resourceURL = epubFileURL.appendingPathComponent(self.opfFilePath).deletingLastPathComponent()
            self.updateState(.normal)
            completion?(.success(()))
            return
        }

        mainQueue.async {
            do {
                let rootURL = self.temporaryDirectoryFileURL
                let zip = try ZIP(fileURL: self.epubFileURL)

                try zip.unarchiveItems(to: rootURL)
                DispatchQueue.main.sync {
                    self.resourceURL = rootURL.appendingPathComponent(self.opfFilePath).deletingLastPathComponent()
                    self.updateState(.normal)
                    self.mainQueue.async {
                        completion?(.success(()))
                    }
                }
            } catch {
                self.updateState(.error(error))
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
            self.updateState(.closed)
            completion?(.success(()))
            return
        }

        do {
            try FileManager.default.removeItem(at: self.temporaryDirectoryFileURL)
            self.updateState(.closed)
            completion?(.success(()))
        } catch {
            completion?(.failure(error))
        }
    }

    private func updateState(_ state: State) {
        DispatchQueue.main.async { [weak self]() in
            self?.state = state
        }
    }
}

extension EPUB: Identifiable {
    public var id: UUID {
        return self.metadata?.bookID ?? UUID.empty
    }
}

extension EPUB: Equatable {
    public static func == (lhs: EPUB, rhs: EPUB) -> Bool {
        return lhs.id == rhs.id
    }
}

extension EPUB {
    enum FileHandler {
        case zip(ZIP)
        case fileWrapper(FileWrapper)
    }
}

extension EPUB.FileHandler {
    func loadFileData(filename: String) throws -> Data? {
        switch self {
        case .zip(let zip):
            return try zip.loadFile(filename: filename)?.data
        case .fileWrapper(let fileWrapper):
            return fileWrapper[filename]?.regularFileContents
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

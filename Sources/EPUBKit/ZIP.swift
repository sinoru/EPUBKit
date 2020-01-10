//
//  ZIP.swift
//  
//
//  Created by Jaehong Kang on 2020/01/09.
//

import Foundation
import CMinizip

class ZIP {
    let fileURL: URL
    var zipReader: UnsafeMutableRawPointer? = nil

    private let mainQueue = DispatchQueue.init(label: "\(String(reflecting: ZIP.self)).main")

    init(fileURL url: URL) throws {
        self.fileURL = url

        var error = MZ_OK

        mz_zip_reader_create(&zipReader);
        error = mz_zip_reader_open_file(zipReader, url.path)
        guard error == MZ_OK else {
            throw ZIP.Error(code: error)
        }
    }

    deinit {
        mz_zip_reader_delete(&zipReader)
    }

    func loadFile(filename: String, caseSensitive: Bool = false, completion: @escaping (Result<Item, Error>) -> Void) {
        mainQueue.async {
            var error = MZ_OK

            let filenameCString = filename.cString(using: .utf8)

            error = mz_zip_reader_locate_entry(self.zipReader, filenameCString, caseSensitive ? 0 : 1)
            guard error == MZ_OK else {
                completion(.failure(ZIP.Error(code: error)))
                return
            }

            var file: UnsafeMutablePointer<mz_zip_file>?

            error = mz_zip_reader_entry_get_info(self.zipReader, &file)
            guard error == MZ_OK else {
                completion(.failure(ZIP.Error(code: error)))
                return
            }

            let bufferLength = mz_zip_reader_entry_save_buffer_length(self.zipReader)

            var buffer = [UInt8](repeating: 0x00, count: Int(bufferLength))

            error = mz_zip_reader_entry_save_buffer(self.zipReader, &buffer, bufferLength)
            guard error == MZ_OK else {
                completion(.failure(ZIP.Error(code: error)))
                return
            }

            completion(.success(.init(filename: file.flatMap({ String(cString: $0.pointee.filename) }) ?? filename, data: Data(buffer))))
        }
    }
}

extension ZIP {
    struct Error: Swift.Error {
        var code: Int32
    }
}

extension ZIP {
    struct Item {
        var filename: String
        var data: Data
    }
}

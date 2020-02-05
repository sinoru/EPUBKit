//
//  ZIP.swift
//  EPUBKit
//

import Foundation

import CMinizip

class ZIP {
    let fileURL: URL
    var zipReader: UnsafeMutableRawPointer?

    init(fileURL url: URL) throws {
        self.fileURL = url

        var error = MZ_OK

        mz_zip_reader_create(&zipReader)
        error = mz_zip_reader_open_file(zipReader, url.path)
        guard error == MZ_OK else {
            throw ZIP.Error(code: error)
        }
    }

    deinit {
        mz_zip_reader_close(zipReader)
        mz_zip_reader_delete(&zipReader)
    }

    func loadFile(filename: String, caseSensitive: Bool = false) throws -> Item? {
        var error = MZ_OK

        let filenameCString = filename.cString(using: .utf8)

        error = mz_zip_reader_locate_entry(self.zipReader, filenameCString, caseSensitive ? 0 : 1)
        guard error == MZ_OK else {
            if error == MZ_END_OF_LIST {
                return nil
            } else {
                throw ZIP.Error(code: error)
            }
        }

        var file: UnsafeMutablePointer<mz_zip_file>?

        error = mz_zip_reader_entry_get_info(self.zipReader, &file)
        guard error == MZ_OK else {
            throw ZIP.Error(code: error)
        }

        let bufferLength = mz_zip_reader_entry_save_buffer_length(self.zipReader)

        var buffer = [UInt8](repeating: 0x00, count: Int(bufferLength))

        error = mz_zip_reader_entry_save_buffer(self.zipReader, &buffer, bufferLength)
        guard error == MZ_OK else {
            throw ZIP.Error(code: error)
        }

        return .init(filename: file.flatMap({ String(cString: $0.pointee.filename) }) ?? filename, data: Data(buffer))
    }

    func unarchiveItems(to dstURL: URL, progressHandler: ((Double) -> Void)? = nil) throws {
        var progressHandler = Unmanaged.passRetained(progressHandler as AnyObject)

        let progressCallback: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutablePointer<mz_zip_file>?, Int64) -> Int32 = { handle, userData, fileInfo, position in
            var raw = UInt8(0)
            mz_zip_reader_get_raw(handle, &raw)

            guard let fileInfo = fileInfo?.pointee else {
                fatalError()
            }

            if let userDataRawPointer = userData {
                let userData = userDataRawPointer.assumingMemoryBound(to: AnyObject.self)

                if let progressHandler = Unmanaged<AnyObject>.fromOpaque(userData).takeRetainedValue() as? ((Double) -> Void) {
                    let progress: Double
                    if raw > 0 && fileInfo.compressed_size > 0 {
                        progress = Double(position) / Double(fileInfo.compressed_size) * 100
                    } else if raw == 0 && fileInfo.uncompressed_size > 0 {
                        progress = Double(position) / Double(fileInfo.uncompressed_size) * 100
                    } else {
                        progress = -1
                    }

                    progressHandler(progress)
                }
            }

            return MZ_OK
        }

        mz_zip_reader_set_progress_cb(zipReader, progressHandler.toOpaque(), progressCallback)
        defer {
            mz_zip_reader_set_progress_cb(zipReader, nil, nil)
            progressHandler.release()
        }

        var error = MZ_OK

        error = mz_zip_reader_save_all(zipReader, dstURL.path.cString(using: .utf8))
        guard error == MZ_OK || error == MZ_END_OF_LIST else {
            throw ZIP.Error(code: error)
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

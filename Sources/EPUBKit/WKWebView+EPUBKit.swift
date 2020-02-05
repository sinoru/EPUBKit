//
//  WKWebView+EPUBKit.swift
//  EPUBKit
//

#if canImport(WebKit)
import WebKit

extension WKWebView {
    enum Request {
        case urlRequest(URLRequest)
        case htmlString(String, baseURL: URL? = nil)
        case data(Data, mimeType: String, characterEncodingName: String, baseURL: URL)
        case fileURL(URL, allowingReadAccessTo: URL)
    }

    @discardableResult
    func load(_ request: Request) -> WKNavigation? {
        switch request {
        case .urlRequest(let urlRequest):
            return load(urlRequest)
        case .htmlString(let htmlString, baseURL: let baseURL):
            return loadHTMLString(htmlString, baseURL: baseURL)
        case .data(let data, mimeType: let mimeType, characterEncodingName: let characterEncodingName, baseURL: let baseURL):
            return load(data, mimeType: mimeType, characterEncodingName: characterEncodingName, baseURL: baseURL)
        case .fileURL(let fileURL, allowingReadAccessTo: let readAccessURL):
            return loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        }
    }
}
#endif

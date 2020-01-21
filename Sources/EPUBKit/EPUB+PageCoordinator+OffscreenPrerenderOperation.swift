//
//  EPUB+PageCoordinator+OffscreenPrerenderOperation.swift
//  
//
//  Created by Jaehong Kang on 2020/01/16.
//

import SNFoundation

#if canImport(CoreGraphics) && canImport(WebKit)
import CoreGraphics
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

extension EPUB.PageCoordinator {
    class OffscreenPrerenderOperation: AsynchronousOperation<CGFloat, Swift.Error> {
        let request: WKWebView.Request
        let pageWidth: CGFloat

        lazy var webView: WKWebView = {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(self, name: "$")
            configuration.userContentController.addUserScript(.init(
                source: """
                    window.addEventListener('load', (event) => {
                        window.webkit.messageHandlers.$.postMessage(null)
                    })
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))

            let webView = WKWebView(frame: CGRect(origin: .zero, size: .init(width: 100, height: 100)), configuration: configuration)

            webView.navigationDelegate = self

            return webView
        }()

        init(request: WKWebView.Request, pageWidth: CGFloat) {
            self.request = request
            self.pageWidth = pageWidth
            super.init()

            self.state = .ready
        }

        override func start() {
            guard case .ready = state else {
                return
            }

            self.webView.frame.size.width = self.pageWidth
            self.webView.load(self.request)
            self.state = .executing
        }

        override func cancel() {
            self.webView.stopLoading()
            self.state = .cancelled
        }
    }
}

extension EPUB.PageCoordinator.OffscreenPrerenderOperation: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        state = .finished(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        state = .finished(.failure(error))
    }
}

extension EPUB.PageCoordinator.OffscreenPrerenderOperation: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        webView.evaluateJavaScript("document.body.scrollHeight") { [unowned self](scrollHeight, error) in
            guard let scrollHeight = scrollHeight as? CGFloat else {
                self.state = .finished(.failure(error!))
                return
            }

            self.state = .finished(.success(scrollHeight))
        }
    }
}

#endif

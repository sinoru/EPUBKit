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

extension EPUB.PageCoordinator {
    class OffscreenPrerenderOperation: AsynchronousOperation<CGFloat, Swift.Error> {
        private static let processPool = WKProcessPool()

        let request: WKWebView.Request
        let pageWidth: CGFloat

        lazy var webView: WKWebView = {
            let configuration = WKWebViewConfiguration()
            configuration.processPool = Self.processPool

            let webView = WKWebView(frame: CGRect(origin: .zero, size: .init(width: 100, height: 100)), configuration: configuration)

            webView.configuration.userContentController.add(self.weakScriptMessageHandler, name: "$")
            webView.configuration.userContentController.addUserScript(.init(
                source: """
                    window.addEventListener('load', (event) => {
                        window.webkit.messageHandlers.$.postMessage(null)
                    })
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
            webView.navigationDelegate = self

            return webView
        }()

        override var state: AsynchronousOperation<CGFloat, Error>.State? {
            didSet {
                switch state {
                case .cancelled, .finished:
                    webView.stopLoading()
                    webView.navigationDelegate = nil
                default:
                    break
                }
            }
        }

        init(request: WKWebView.Request, pageWidth: CGFloat) {
            self.request = request
            self.pageWidth = pageWidth
            super.init()

            self.state = .ready
        }

        deinit {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "$")
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
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self](scrollHeight, error) in
            guard let scrollHeight = scrollHeight as? CGFloat else {
                self?.state = .finished(.failure(error!))
                return
            }

            self?.state = .finished(.success(scrollHeight))
        }
    }
}

#endif

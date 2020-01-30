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
    class OffscreenPrerenderOperation: AsynchronousOperation<EPUB.ItemContentInfo, Swift.Error> {
        private static let processPool = WKProcessPool()

        let request: WKWebView.Request
        let pageWidth: CGFloat

        lazy var webView: WKWebView = {
            let configuration = WKWebViewConfiguration()
            configuration.processPool = Self.processPool

            let webView = WKWebView(frame: .zero, configuration: configuration)

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

        override var state: AsynchronousOperation<EPUB.ItemContentInfo, Error>.State? {
            didSet {
                switch state {
                case .cancelled, .finished:
                    DispatchQueue.main.async {
                        self.webView.stopLoading()
                        self.webView.navigationDelegate = nil
                    }
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
            DispatchQueue.main.async { [webView] in // For dealloc operation in Main Thread
                webView.configuration.userContentController.removeScriptMessageHandler(forName: "$")
            }
        }

        override func start() {
            switch state {
            case .ready:
                self.state = .executing
                DispatchQueue.main.async {
                    self.webView.frame.size = CGSize(width: self.pageWidth, height: .greatestFiniteMagnitude)
                    self.webView.load(self.request)
                }
            case .cancelled:
                self.state = .executing
                self.state = .cancelled
            default:
                break
            }
        }

        override func cancel() {
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
        webView.evaluateJavaScript("""
        new Object({
            scrollWidth: document.body.scrollWidth,
            scrollHeight: document.body.scrollHeight,
            contentYOffsetsByID: Array.from(document.querySelectorAll('*[id]')).reduce((r, v) => { return {...r, [v.id]: v.getBoundingClientRect().y }}, {})
        })
        """) { [weak self](result, error) in
            do {
                guard let result = result as? [String: Any] else {
                    throw error ?? EPUB.Error.unknown
                }

                guard let scrollWidth = result["scrollWidth"] as? Double else {
                    throw EPUB.Error.unknown
                }

                guard let scrollHeight = result["scrollHeight"] as? Double else {
                    throw EPUB.Error.unknown
                }

                guard let contentYOffsetsByID = result["contentYOffsetsByID"] as? [String: Double] else {
                    throw EPUB.Error.unknown
                }

                self?.state = .finished(.success(.init(
                    contentSize: CGSize(width: scrollWidth, height: scrollHeight),
                    contentYOffsetsByID: contentYOffsetsByID.mapValues({ CGFloat($0) })
                )))
            } catch {
                self?.state = .finished(.failure(error))
            }
        }
    }
}

#endif

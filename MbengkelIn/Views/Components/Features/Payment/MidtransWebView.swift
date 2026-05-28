import SwiftUI
import WebKit

struct MidtransWebView: UIViewRepresentable {
    let url: URL
    var onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let urlString = navigationAction.request.url?.absoluteString,
               urlString.contains("transaction_status") || urlString.contains("status_code") {
                decisionHandler(.cancel)
                onFinish()
                return
            }
            decisionHandler(.allow)
        }
    }
}

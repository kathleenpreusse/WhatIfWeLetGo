import UIKit
import WebKit
import StoreKit

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler, SKPaymentTransactionObserver {
    
    var webView: WKWebView!
    let tipProductID = "com.kathleenpreusse.whatifweletgo1.tip"
    var tipProduct: SKProduct?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add payment observer
        SKPaymentQueue.default().add(self)
        
        // Fetch the IAP product from App Store Connect
        fetchTipProduct()
        
        // Set up web view with message handler so web app can trigger IAP
        let contentController = WKUserContentController()
        contentController.add(self, name: "iapBridge")
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.userContentController = contentController
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1 WhatIfWeLetGo/iOS"
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        DispatchQueue.main.async {
            if let url = URL(string: "https://what-if-we-let-go.web.app") {
                let request = URLRequest(url: url)
                self.webView.load(request)
            }
        }
        
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = false
    }
    
    // MARK: - StoreKit: Fetch Product
    func fetchTipProduct() {
        let request = SKProductsRequest(productIdentifiers: [tipProductID])
        request.delegate = self
        request.start()
    }
    
    // MARK: - StoreKit: Initiate Purchase
    func purchaseTip() {
        guard SKPaymentQueue.canMakePayments() else {
            sendToWeb("iapResult", data: ["status": "disabled"])
            return
        }
        guard let product = tipProduct else {
            sendToWeb("iapResult", data: ["status": "unavailable"])
            return
        }
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    // MARK: - Bridge: Receive message from web app
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "iapBridge" {
            if let body = message.body as? String, body == "tipRequested" {
                purchaseTip()
            }
        }
    }
    
    // MARK: - Bridge: Send message back to web app
    func sendToWeb(_ event: String, data: [String: String]) {
        let json = data.map { "\"\($0.key)\": \"\($0.value)\"" }.joined(separator: ", ")
        let js = "window.dispatchEvent(new CustomEvent('\(event)', { detail: { \(json) } }));"
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    // MARK: - SKPaymentTransactionObserver
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                sendToWeb("iapResult", data: ["status": "success"])
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
                sendToWeb("iapResult", data: ["status": "failed"])
            case .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
                sendToWeb("iapResult", data: ["status": "success"])
            default:
                break
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
}

// MARK: - SKProductsRequestDelegate
extension ViewController: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if let product = response.products.first {
            tipProduct = product
        }
    }
}

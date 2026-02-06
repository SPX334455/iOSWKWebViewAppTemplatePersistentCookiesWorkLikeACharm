import UIKit
import WebKit

class ViewController: UIViewController {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    private var isPanelVisible = true

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var shouldAutorotate: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebViews()
        setupControls()
        
        // Görüntü senkronizasyonu (FPS: 20 - iPad'i yormamak için ideal)
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }

    func setupWebViews() {
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            ctx.fillStyle = "black";
            ctx.fillRect(0,0,1280,720);

            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { 
                    ctx.clearRect(0,0,1280,720);
                    ctx.drawImage(img, 0, 0, 1280, 720); 
                };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            navigator.mediaDevices.getUserMedia = function(c) {
                return Promise.resolve(canvas.captureStream(30));
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        view.addSubview(webView)

        preziView = WKWebView(frame: .zero)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderColor = UIColor.green.cgColor
        preziView.layer.borderWidth = 2
        view.addSubview(preziView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10),
            preziView.widthAnchor.constraint(equalToConstant: 240),
            preziView.heightAnchor.constraint(equalToConstant: 135)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/?embed=1")!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let bP = createBtn(title: " ⬅️ ", action: #selector(goP))
        let bF = createBtn(title: " TAM EKRAN ", action: #selector(goFull))
        let bN = createBtn(title: " ➡️ ", action: #selector(goN))
        let bT = createBtn(title: " PANELİ GİZLE ", action: #selector(togglePanel))
        
        [bP, bF, bN, bT].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -15),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    func createBtn(title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.backgroundColor = .black.withAlphaComponent(0.8)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    // --- PANEL GİZLE/GÖSTER ---
    @objc func togglePanel() {
        isPanelVisible.toggle()
        preziView.isHidden = !isPanelVisible
        // Buton metnini güncellemek için stack içindeki butonu bulalım
        if let stack = view.subviews.last as? UIStackView, let btn = stack.arrangedSubviews.last as? UIButton {
            btn.setTitle(isPanelVisible ? " PANELİ GİZLE " : " PANELİ AÇ ", for: .normal)
        }
    }

    // --- YENİ WEBGL KONTROLLERİ ---
    @objc func goFull() {
        let js = "document.querySelector('.webgl-viewer-navbar-button-fullscreen')?.click();"
        preziView.evaluateJavaScript(js)
    }

    @objc func goP() {
        // Sol ok için navbar-left içindeki etkileşimi tetikle
        let js = "document.querySelector('.webgl-viewer-navbar-left')?.click();"
        preziView.evaluateJavaScript(js)
    }

    @objc func goN() {
        // Sağ ok için navbar-right içindeki etkileşimi tetikle
        let js = "document.querySelector('.webgl-viewer-navbar-right')?.click();"
        preziView.evaluateJavaScript(js)
    }

    @objc func syncFrames() {
        preziView.takeSnapshot(with: nil) { img, _ in
            guard let i = img, let d = i.jpegData(compressionQuality: 0.5) else { return }
            self.webView.evaluateJavaScript("window.drawToFakeCamera('\(d.base64EncodedString())');")
        }
    }
}

extension ViewController: WKUIDelegate {
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

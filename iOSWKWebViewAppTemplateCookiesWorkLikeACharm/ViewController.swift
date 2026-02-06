import UIKit
import WebKit

class ViewController: UIViewController {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    private var isPanelVisible = true
    private var preziTrailingConstraint: NSLayoutConstraint!

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscapeLeft }
    override var shouldAutorotate: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebViews()
        setupControls()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }

    func setupWebViews() {
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
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

            // DOKUNMA SİMÜLASYONU FONKSİYONU
            window.simulateTouch = function(selector) {
                var el = document.querySelector(selector);
                if (!el) return;
                ['touchstart', 'touchend'].forEach(type => {
                    var t = new Touch({identifier: Date.now(), target: el, clientX: 0, clientY: 0});
                    el.dispatchEvent(new TouchEvent(type, {touches: [t], targetTouches: [t], changedTouches: [t], bubbles: true}));
                });
                el.click(); // Yedek olarak click de gönder
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

        preziTrailingConstraint = preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziTrailingConstraint,
            preziView.widthAnchor.constraint(equalToConstant: 240),
            preziView.heightAnchor.constraint(equalToConstant: 135)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/?embed=1")!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        let bP = createBtn(title: " ⬅️ SOL ", action: #selector(goP))
        let bF = createBtn(title: " 🔳 TAM EKRAN ", action: #selector(goFull))
        let bN = createBtn(title: " SAĞ ➡️ ", action: #selector(goN))
        let bT = createBtn(title: " PANEL GİZLE/AÇ ", action: #selector(togglePanel))
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
        b.backgroundColor = .black.withAlphaComponent(0.85); b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc func togglePanel() {
        isPanelVisible.toggle()
        preziTrailingConstraint.constant = isPanelVisible ? -10 : 2500
        UIView.animate(withDuration: 0.4) { self.view.layoutIfNeeded() }
    }

    // --- NOKTA ATIŞI KOMUTLAR ---
    @objc func goFull() {
        preziView.evaluateJavaScript("window.simulateTouch('.webgl-viewer-navbar-button-fullscreen');")
    }

    @objc func goP() {
        // Ok tuşunu hem dokunma hem klavye olarak zorla
        let js = """
        window.focus();
        window.simulateTouch('.webgl-viewer-navbar-left');
        document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, which: 37, bubbles: true}));
        """
        preziView.evaluateJavaScript(js)
    }

    @objc func goN() {
        let js = """
        window.focus();
        window.simulateTouch('.webgl-viewer-navbar-right');
        document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, which: 39, bubbles: true}));
        """
        preziView.evaluateJavaScript(js)
    }

    @objc func syncFrames() {
        preziView.takeSnapshot(with: nil) { img, _ in
            guard let i = img, let d = i.jpegData(compressionQuality: 0.4) else { return }
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(d.base64EncodedString())');}")
        }
    }
}

extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

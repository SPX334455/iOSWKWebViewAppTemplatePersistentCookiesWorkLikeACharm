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
        // Krtik: İlk başta etkileşimi engellememesi için ayar
        preziView.isUserInteractionEnabled = true 
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

    @objc func togglePanel() {
        isPanelVisible.toggle()
        // Kendi kamerandan gitmemesi için gizlemiyoruz, ŞEFFAFLAŞTIRIYORUZ.
        preziView.alpha = isPanelVisible ? 1.0 : 0.01 
        if let stack = view.subviews.last as? UIStackView, let btn = stack.arrangedSubviews.last as? UIButton {
            btn.setTitle(isPanelVisible ? " PANELİ GİZLE " : " PANELİ AÇ ", for: .normal)
        }
    }

    // --- KLAVYE SİMÜLASYONU (Daha Garantidir) ---
    @objc func goFull() {
        // Tam ekran butonu için verdiğin klası kullanıyoruz
        preziView.evaluateJavaScript("document.querySelector('.webgl-viewer-navbar-button-fullscreen')?.click();")
    }

    @objc func goP() {
        let js = "window.dispatchEvent(new KeyboardEvent('keydown', {'keyCode': 37, 'which': 37}));"
        preziView.evaluateJavaScript(js)
    }

    @objc func goN() {
        let js = "window.dispatchEvent(new KeyboardEvent('keydown', {'keyCode': 39, 'which': 39}));"
        preziView.evaluateJavaScript(js)
    }

    @objc func syncFrames() {
        // Alpha 0.01 olduğu için hala snapshot alabilir
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

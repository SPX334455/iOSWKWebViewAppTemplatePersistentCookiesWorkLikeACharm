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
        // --- BU SCRIPT PREZI'YI KONTROL ETMEK İÇİN ENJEKTE EDİLECEK ---
        let controlJS = """
        window.pressKey = function(k) {
            var e = new KeyboardEvent('keydown', {
                keyCode: k, which: k, bubbles: true, cancelable: true, view: window
            });
            document.dispatchEvent(e);
            document.body.dispatchEvent(e);
            // WebGL Canvas'a direkt odaklan ve gönder
            var canvas = document.querySelector('canvas');
            if(canvas) {
                canvas.focus();
                canvas.dispatchEvent(e);
            }
        };
        """

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
        })();
        """
        
        let config = WKWebViewConfiguration()
        // Her iki scripti de ekliyoruz
        config.userContentController.addUserScript(WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.userContentController.addUserScript(WKUserScript(source: controlJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        view.addSubview(webView)

        preziView = WKWebView(frame: .zero, configuration: config)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderColor = UIColor.green.cgColor
        preziView.layer.borderWidth = 2
        preziView.isUserInteractionEnabled = true 
        view.addSubview(preziView)

        preziTrailingConstraint = preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziTrailingConstraint,
            preziView.widthAnchor.constraint(equalToConstant: 350), 
            preziView.heightAnchor.constraint(equalToConstant: 200)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let bP = createBtn(title: "  ⬅️ GERİ  ", action: #selector(goP))
        let bN = createBtn(title: "  İLERİ ➡️  ", action: #selector(goN))
        let bT = createBtn(title: "  PANEL GİZLE  ", action: #selector(togglePanel))
        
        [bP, bN, bT].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.heightAnchor.constraint(equalToConstant: 55)
        ])
    }

    func createBtn(title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .boldSystemFont(ofSize: 18)
        b.backgroundColor = .systemBlue; b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 15
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc func togglePanel() {
        isPanelVisible.toggle()
        preziTrailingConstraint.constant = isPanelVisible ? -10 : 3000
        UIView.animate(withDuration: 0.4) { self.view.layoutIfNeeded() }
    }

    @objc func goP() {
        // Prezi'yi öne çıkar ve 37 (Sol Ok) tuşunu bas
        preziView.evaluateJavaScript("window.focus(); window.pressKey(37);")
    }

    @objc func goN() {
        // Prezi'yi öne çıkar ve 39 (Sağ Ok) tuşunu bas
        preziView.evaluateJavaScript("window.focus(); window.pressKey(39);")
    }

    @objc func syncFrames() {
        preziView.takeSnapshot(with: nil) { img, _ in
            guard let i = img, let d = i.jpegData(compressionQuality: 0.5) else { return }
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(d.base64EncodedString())');}")
        }
    }
}

@available(iOS 15.0, *)
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

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
        // Krtik: Tıklamaları Prezi'ye geçirmesi için
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
            // Paneli biraz büyüttüm ki Prezi butonları sığsın
            preziView.widthAnchor.constraint(equalToConstant: 320), 
            preziView.heightAnchor.constraint(equalToConstant: 180)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        
        // 🔴 BURASI DEĞİŞTİ: Artık kısıtlamasız orijinal Prezi linki
        let preziLink = "https://prezi.com/p/wckx0wlz288z/"
        preziView.load(URLRequest(url: URL(string: preziLink)!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 15; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let bP = createBtn(title: " ⬅️ ", action: #selector(goP))
        let bN = createBtn(title: " ➡️ ", action: #selector(goN))
        let bT = createBtn(title: " PANELİ GİZLE/AÇ ", action: #selector(togglePanel))
        
        [bP, bN, bT].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -15),
            stack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func createBtn(title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.backgroundColor = .black.withAlphaComponent(0.85); b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 12
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc func togglePanel() {
        isPanelVisible.toggle()
        preziTrailingConstraint.constant = isPanelVisible ? -10 : 2500
        UIView.animate(withDuration: 0.4) { self.view.layoutIfNeeded() }
    }

    @objc func goP() {
        preziView.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, which: 37, bubbles: true}));")
    }

    @objc func goN() {
        preziView.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, which: 39, bubbles: true}));")
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

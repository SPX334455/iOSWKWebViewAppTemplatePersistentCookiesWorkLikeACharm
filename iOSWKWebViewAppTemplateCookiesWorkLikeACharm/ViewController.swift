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
        // Görüntü akışını saniyede 15 kareye sabitledik (Hem akıcı hem stabil)
        timer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
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

        // Umingle - Ana Ekran
        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        view.addSubview(webView)

        // Prezi - Kaynak Ekran
        preziView = WKWebView(frame: .zero)
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
            // Daha rahat manüel kontrol için ideal boyut
            preziView.widthAnchor.constraint(equalToConstant: 350), 
            preziView.heightAnchor.constraint(equalToConstant: 200)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    func setupControls() {
        let bT = UIButton(type: .system)
        bT.translatesAutoresizingMaskIntoConstraints = false
        bT.setTitle(" PANELİ GİZLE / AÇ ", for: .normal)
        bT.titleLabel?.font = .boldSystemFont(ofSize: 16)
        bT.backgroundColor = .systemRed // Dikkat çekici olması için kırmızı
        bT.setTitleColor(.white, for: .normal)
        bT.layer.cornerRadius = 20
        bT.addTarget(self, action: #selector(togglePanel), for: .touchUpInside)
        
        view.addSubview(bT)
        
        NSLayoutConstraint.activate([
            bT.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bT.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bT.widthAnchor.constraint(equalToConstant: 200),
            bT.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc func togglePanel() {
        isPanelVisible.toggle()
        // Paneli ekranın çok dışına itiyoruz (Snapshot durmasın diye)
        preziTrailingConstraint.constant = isPanelVisible ? -10 : 3000
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    @objc func syncFrames() {
        // Snapshot alırken hata kontrolü ekledik
        preziView.takeSnapshot(with: nil) { img, error in
            if let i = img, error == nil {
                if let d = i.jpegData(compressionQuality: 0.6) {
                    let base64 = d.base64EncodedString()
                    self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(base64)');}")
                }
            }
        }
    }
}

@available(iOS 15.0, *)
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

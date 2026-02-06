import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {
    
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    let umingleURL = URL(string: "https://umingle.com")!

    // 📱 EKRANI YATAY TUTMAK İÇİN
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestNativePermissions()
        setupStatusbar()
        setupWebViews()
        setupControls()
        
        // Aktarımı başlat
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }
    
    func requestNativePermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    func setupWebViews() {
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            
            // Başlangıçta siteye "Yükleniyor" görüntüsü verelim (Siyah kalmasın)
            ctx.fillStyle = "blue";
            ctx.fillRect(0,0,1280,720);
            ctx.fillStyle = "white";
            ctx.font = "40px Arial";
            ctx.fillText("Sanal Kamera Aktif - Prezi Bekleniyor...", 100, 360);

            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { 
                    ctx.clearRect(0, 0, 1280, 720);
                    ctx.drawImage(img, 0, 0, 1280, 720); 
                };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            // 🟢 KRİTİK: Cihazları siteye zorla kabul ettir
            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([
                    {deviceId:'virt-cam', kind:'videoinput', label:'FaceTime HD Camera', groupId:'g1'},
                    {deviceId:'virt-mic', kind:'audioinput', label:'Built-in Microphone', groupId:'g2'}
                ]);
            };

            function getFakeStream() {
                var stream = canvas.captureStream(30);
                var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
                var dst = audioCtx.createMediaStreamDestination();
                stream.addTrack(dst.stream.getAudioTracks()[0] || new MediaStreamTrack());
                return stream;
            }

            // Site kamera istediğinde akışı bağla
            navigator.mediaDevices.getUserMedia = function(c) { return Promise.resolve(getFakeStream()); };
            
            // WebRTC bağlantılarını yakala
            var origAddTrack = RTCPeerConnection.prototype.addTrack;
            RTCPeerConnection.prototype.addTrack = function(track, stream) {
                if (track.kind === 'video') {
                    return origAddTrack.call(this, canvas.captureStream(30).getVideoTracks()[0], stream);
                }
                return origAddTrack.call(this, track, stream);
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.allowsInlineMediaPlayback = true
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        // Masaüstü Chrome gibi davran (En stabil mod)
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36"
        self.view.addSubview(webView)
        
        preziView = WKWebView(frame: .zero)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderWidth = 3
        preziView.layer.borderColor = UIColor.green.cgColor
        self.view.addSubview(preziView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.view.topAnchor),
            webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            preziView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -10),
            preziView.widthAnchor.constraint(equalToConstant: 240),
            preziView.heightAnchor.constraint(equalToConstant: 135)
        ])
        
        webView.load(URLRequest(url: umingleURL))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/?embed=1")!))
        self.view.bringSubviewToFront(preziView)
    }

    func setupStatusbar() {
        let v = UIView()
        v.backgroundColor = .systemPink
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: view.topAnchor),
            v.widthAnchor.constraint(equalTo: view.widthAnchor),
            v.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 20; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let b1 = UIButton(type: .system); b1.setTitle(" ⬅️ ", for: .normal); b1.addTarget(self, action: #selector(goPrev), for: .touchUpInside)
        let b2 = UIButton(type: .system); b2.setTitle(" BAŞLAT ", for: .normal); b2.addTarget(self, action: #selector(forcePlay), for: .touchUpInside)
        let b3 = UIButton(type: .system); b3.setTitle(" ➡️ ", for: .normal); b3.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        
        [b1, b2, b3].forEach {
            $0.backgroundColor = .black; $0.setTitleColor(.white, for: .normal); $0.layer.cornerRadius = 10
            stack.addArrangedSubview($0)
        }
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
        view.bringSubviewToFront(stack)
    }

    @objc func goPrev() { preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, bubbles: true}));") }
    @objc func goNext() { preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, bubbles: true}));") }
    @objc func forcePlay() {
        preziView.evaluateJavaScript("document.querySelector('.prezi-player-icon-play')?.click(); document.querySelector('.present-button')?.click();")
    }

    @objc func syncFrames() {
        preziView.takeSnapshot(with: nil) { img, _ in
            guard let i = img, let d = i.jpegData(compressionQuality: 0.5) else { return }
            let b = d.base64EncodedString()
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(b)');}")
        }
    }
}

// MARK: - İzinler ve Çerezler
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        webView.loadDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.writeDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
}

extension WKWebView {
    func writeDiskCookies(for d: String, completion: @escaping () -> ()) {
        var dict = [String: Any]()
        self.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            for c in cookies { if c.domain.contains(d) { dict[c.name] = c.properties } }
            UserDefaults.standard.set(dict, forKey: "cookies_" + d)
            completion()
        }
    }
    func loadDiskCookies(for d: String, completion: @escaping () -> ()) {
        if let disk = UserDefaults.standard.dictionary(forKey: "cookies_" + d) {
            for (_, cfg) in disk {
                if let c = HTTPCookie(properties: cfg as! [HTTPCookiePropertyKey : Any]) {
                    self.configuration.websiteDataStore.httpCookieStore.setCookie(c)
                }
            }
        }
        completion()
    }
}

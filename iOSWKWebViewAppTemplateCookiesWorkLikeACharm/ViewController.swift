import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {
    
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    let umingleURL = URL(string: "https://umingle.com")!

    // 1. EKRANI YATAYDA SABİTLE (iOS 16+ VE ÖNCESİ İÇİN)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if #available(iOS 16.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        requestNativePermissions()
        setupStatusbar()
        setupWebViews()
        setupControls()
        timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }
    
    func requestNativePermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    func setupWebViews() {
        // --- SAHTE KAMERA SCRİPTİ ---
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            
            // İlk açılışta siyah ekran yerine mavi bir ekran verelim (Çalıştığını anlamak için)
            ctx.fillStyle = "blue";
            ctx.fillRect(0,0,1280,720);
            ctx.fillStyle = "white";
            ctx.font = "30px Arial";
            ctx.fillText("Sanal Kamera Aktif - Prezi Bekleniyor", 50, 360);

            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { 
                    ctx.clearRect(0,0,1280,720);
                    ctx.drawImage(img, 0, 0, 1280, 720); 
                };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([
                    {deviceId:'v-cam', kind:'videoinput', label:'FaceTime HD Camera (Built-in)', groupId:'g1'},
                    {deviceId:'v-mic', kind:'audioinput', label:'Internal Microphone', groupId:'g2'}
                ]);
            };

            function getStream() {
                var stream = canvas.captureStream(30);
                var ac = new (window.AudioContext || window.webkitAudioContext)();
                var dst = ac.createMediaStreamDestination();
                stream.addTrack(dst.stream.getAudioTracks()[0] || new MediaStreamTrack());
                return stream;
            }

            navigator.mediaDevices.getUserMedia = function(c) { return Promise.resolve(getStream()); };
            
            var orig = RTCPeerConnection.prototype.addTrack;
            RTCPeerConnection.prototype.addTrack = function(t, s) {
                if (t.kind === 'video') { return orig.call(this, canvas.captureStream(30).getVideoTracks()[0], s); }
                return orig.call(this, t, s);
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.allowsInlineMediaPlayback = true
        
        // 🖥️ KENDİNİ BİLGİSAYAR OLARAK TANIT (SİTEYİ KANDIRMAK İÇİN)
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
        self.view.addSubview(webView)
        
        preziView = WKWebView(frame: .zero)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderWidth = 2
        preziView.layer.borderColor = UIColor.green.cgColor
        self.view.addSubview(preziView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10),
            preziView.widthAnchor.constraint(equalToConstant: 240),
            preziView.heightAnchor.constraint(equalToConstant: 135)
        ])
        
        webView.load(URLRequest(url: umingleURL))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/?embed=1")!))
        view.bringSubviewToFront(preziView)
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
        let b1 = UIButton(type: .system); b1.setTitle(" ⬅️ ", for: .normal); b1.addTarget(self, action: #selector(goP), for: .touchUpInside)
        let b2 = UIButton(type: .system); b2.setTitle(" BAŞLAT ", for: .normal); b2.addTarget(self, action: #selector(fP), for: .touchUpInside)
        let b3 = UIButton(type: .system); b3.setTitle(" ➡️ ", for: .normal); b3.addTarget(self, action: #selector(goN), for: .touchUpInside)
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

    @objc func goP() { preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, bubbles: true}));") }
    @objc func goN() { preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, bubbles: true}));") }
    @objc func fP() {
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

// Delegate ve Cookie fonksiyonları (Değişmedi)
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

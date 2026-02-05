import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {
    
    private var webView: WKWebView! // Ana ekran (Umingle)
    private var preziView: WKWebView! // Sağ üstteki küçük sunum penceresi
    private var timer: Timer?
    let umingleURL = URL(string: "https://umingle.com")!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ses/Kamera oturumunu baştan açıyoruz (Hata almamak için)
        requestNativePermissions()
        
        setupStatusbar()
        setupWebViews()
        setupControls()
        
        // Saniyede 15 kare aktarım
        timer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }
    
    func requestNativePermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    func setupWebViews() {
        // 1. Gelişmiş Sahte Kamera Scripti (İzin hatasını by-pass eder)
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            
            // Boş siyah ekran olmasın diye başlangıçta bir renk atalım
            ctx.fillStyle = "black";
            ctx.fillRect(0,0,1280,720);
            
            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { ctx.drawImage(img, 0, 0, 1280, 720); };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            // WebRTC ve getUserMedia Kancası
            var originalAddTrack = RTCPeerConnection.prototype.addTrack;
            RTCPeerConnection.prototype.addTrack = function(track, stream) {
                if (track.kind === 'video') {
                    console.log("Kamera değiştiriliyor...");
                    var fakeStream = canvas.captureStream(25);
                    return originalAddTrack.call(this, fakeStream.getVideoTracks()[0], stream);
                }
                return originalAddTrack.call(this, track, stream);
            };

            navigator.mediaDevices.getUserMedia = function(constraints) {
                console.log("Kamera izni istendi, sahte stream veriliyor.");
                return Promise.resolve(canvas.captureStream(25));
            };
            
            // Site 'Cihaz var mı?' diye kontrol ederse 'Var' diyoruz
            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([
                    {kind: 'videoinput', label: 'Virtual Camera', deviceId: 'virtual', groupId: '1'},
                    {kind: 'audioinput', label: 'Microphone', deviceId: 'mic', groupId: '1'}
                ]);
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        
        // İZİN AYARLARI (Çok Önemli)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [] // Otomatik oynatma için
        
        // 2. Umingle WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self         // <--- BU ÇOK ÖNEMLİ
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Mobile/15E148 Safari/604.1"
        self.view.addSubview(webView)
        
        // 3. Prezi WebView (Sağ Üst Köşe)
        let preziConfig = WKWebViewConfiguration()
        preziConfig.allowsInlineMediaPlayback = true
        preziView = WKWebView(frame: .zero, configuration: preziConfig)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderWidth = 2
        preziView.layer.borderColor = UIColor.green.cgColor
        self.view.addSubview(preziView)

        // Yerleşim
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: self.view.topAnchor),
            webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            preziView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziView.rightAnchor.constraint(equalTo: self.view.rightAnchor, constant: -10),
            preziView.widthAnchor.constraint(equalToConstant: 200),
            preziView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        webView.load(URLRequest(url: umingleURL))
        // Prezi Linki (Embed parametresiyle)
        let preziURL = URL(string: "https://prezi.com/p/wckx0wlz288z/?embed=1")!
        preziView.load(URLRequest(url: preziURL))
        
        self.view.bringSubviewToFront(preziView)
    }

    func setupStatusbar() {
        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let statusbarView = UIView()
        statusbarView.backgroundColor = UIColor(red: 0.93, green: 0, blue: 1, alpha: 1)
        view.addSubview(statusbarView)
        statusbarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusbarView.heightAnchor.constraint(equalToConstant: statusBarHeight),
            statusbarView.widthAnchor.constraint(equalTo: view.widthAnchor),
            statusbarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusbarView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 30
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let b1 = UIButton(type: .system); b1.setTitle("GERİ", for: .normal); b1.addTarget(self, action: #selector(goPrevPage), for: .touchUpInside)
        let b2 = UIButton(type: .system); b2.setTitle("ODAKLA/BAŞLAT", for: .normal); b2.addTarget(self, action: #selector(forceStart), for: .touchUpInside)
        let b3 = UIButton(type: .system); b3.setTitle("İLERİ", for: .normal); b3.addTarget(self, action: #selector(goNextPage), for: .touchUpInside)
        
        [b1, b2, b3].forEach { 
            $0.backgroundColor = .black.withAlphaComponent(0.8)
            $0.setTitleColor(.white, for: .normal)
            $0.titleLabel?.font = .boldSystemFont(ofSize: 14)
            $0.layer.cornerRadius = 8
            stack.addArrangedSubview($0) 
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            stack.heightAnchor.constraint(equalToConstant: 50),
            stack.widthAnchor.constraint(equalToConstant: 320)
        ])
        view.bringSubviewToFront(stack)
    }

    // Butonların çalışması için "Focus" (Odak) sorunu çözüldü
    @objc func goPrevPage() { 
        preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, which: 37, bubbles: true}));") 
    }
    @objc func goNextPage() { 
        preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, which: 39, bubbles: true}));") 
    }
    @objc func forceStart() { 
        // Hem tıkla hem odakla
        preziView.evaluateJavaScript("""
            window.focus();
            var playBtn = document.querySelector('.prezi-player-icon-play');
            if(playBtn) playBtn.click();
            var presentBtn = document.querySelector('.present-button');
            if(presentBtn) presentBtn.click();
        """)
    }

    @objc func syncFrames() {
        // Sadece Prezi yüklendiğinde snapshot al
        if preziView.isLoading { return }
        
        preziView.takeSnapshot(with: nil) { image, _ in
            guard let img = image, let data = img.jpegData(compressionQuality: 0.4) else { return }
            let b64 = data.base64EncodedString()
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(b64)');}")
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle { return .lightContent }
}

// MARK: - KRİTİK İZİN YÖNETİMİ (BU KISIM HATAYI ÇÖZER)
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    
    // 🔴 İŞTE SİHİRLİ FONKSİYON BU!
    // Site kamera istediğinde iOS'a "Ben kefilim, izin ver" der.
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant) // SORGUSUZ SUALSİZ İZİN VER
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        webView.loadDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.writeDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
}

// Cookie Yönetimi (Değişmedi)
extension WKWebView {
    enum PrefKey { static let cookie = "cookies" }
    func writeDiskCookies(for domain: String, completion: @escaping () -> ()) {
        fetchInMemoryCookies(for: domain) { data in
            UserDefaults.standard.setValue(data, forKey: PrefKey.cookie + domain)
            completion()
        }
    }
    func loadDiskCookies(for domain: String, completion: @escaping () -> ()) {
        if let diskCookie = UserDefaults.standard.dictionary(forKey: (PrefKey.cookie + domain)){
            fetchInMemoryCookies(for: domain) { freshCookie in
                let mergedCookie = diskCookie.merging(freshCookie) { (_, new) in new }
                for (_, cookieConfig) in mergedCookie {
                    let cookie = cookieConfig as! Dictionary<String, Any>
                    var expire : Any? = nil
                    if let expireTime = cookie["Expires"] as? Double { expire = Date(timeIntervalSinceNow: expireTime) }
                    let newCookie = HTTPCookie(properties: [ .domain: cookie["Domain"] as Any, .path: cookie["Path"] as Any, .name: cookie["Name"] as Any, .value: cookie["Value"] as Any, .secure: cookie["Secure"] as Any, .expires: expire as Any ])
                    self.configuration.websiteDataStore.httpCookieStore.setCookie(newCookie!)
                }
                completion()
            }
        } else { completion() }
    }
    func fetchInMemoryCookies(for domain: String, completion: @escaping ([String: Any]) -> ()) {
        var cookieDict = [String: AnyObject]()
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies { if cookie.domain.contains(domain) { cookieDict[cookie.name] = cookie.properties as AnyObject? } }
            completion(cookieDict)
        }
    }
}

import UIKit
import WebKit

class ViewController: UIViewController {
    
    // 1. İki adet WebView tanımlıyoruz
    private var webView: WKWebView! // Ana ekran (Umingle)
    private var preziView: WKWebView! // Gizli ekran (Prezi)
    private var timer: Timer?
    
    // Umingle URL'i
    let umingleURL = URL(string: "https://umingle.com")!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupStatusbar()
        setupWebViews()
        setupControls()
        
        // Sanal Kamera Döngüsü: Saniyede 15 kare
        timer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }
    
    func setupWebViews() {
        // --- SAHTE KAMERA SCRİPTİ ---
        let hookJS = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { ctx.drawImage(img, 0, 0, 1280, 720); };
                img.src = 'data:image/jpeg;base64,' + b64;
            };
            var originalAddTrack = RTCPeerConnection.prototype.addTrack;
            RTCPeerConnection.prototype.addTrack = function(track, stream) {
                if (track.kind === 'video') {
                    var fakeStream = canvas.captureStream(25);
                    return originalAddTrack.call(this, fakeStream.getVideoTracks()[0], stream);
                }
                return originalAddTrack.call(this, track, stream);
            };
            navigator.mediaDevices.getUserMedia = function() {
                return Promise.resolve(canvas.captureStream(25));
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        config.allowsInlineMediaPlayback = true

        // 2. Umingle WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        self.view.addSubview(webView)
        
        // 3. Prezi WebView (Gizli)
        preziView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1280, height: 720))
        // !!! LİNKİNİ AŞAĞIYA KOYMAYI UNUTMA !!!
        let preziURL = URL(string: "https://prezi.com/p/wckx0wlz288z/omegle-game-includes-kinks/")! 
        preziView.load(URLRequest(url: preziURL))

        NSLayoutConstraint.activate([
            webView.leftAnchor.constraint(equalTo: self.view.leftAnchor),
            webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            webView.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            webView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
        ])
        
        webView.load(URLRequest(url: umingleURL))
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
        stack.spacing = 40
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        // İsim çakışmasını önlemek için selector isimlerini değiştirdim:
        let b1 = UIButton(type: .system); b1.setTitle("⬅️", for: .normal); b1.addTarget(self, action: #selector(goPrevPage), for: .touchUpInside)
        let b2 = UIButton(type: .system); b2.setTitle("TAM EKRAN", for: .normal); b2.addTarget(self, action: #selector(goFullScreen), for: .touchUpInside)
        let b3 = UIButton(type: .system); b3.setTitle("➡️", for: .normal); b3.addTarget(self, action: #selector(goNextPage), for: .touchUpInside)
        
        [b1, b2, b3].forEach { 
            $0.backgroundColor = .black.withAlphaComponent(0.6)
            $0.setTitleColor(.white, for: .normal)
            $0.layer.cornerRadius = 10
            stack.addArrangedSubview($0) 
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.heightAnchor.constraint(equalToConstant: 44),
            stack.widthAnchor.constraint(equalToConstant: 300)
        ])
    }

    // Fonksiyon isimlerini sistem isimleriyle çakışmasın diye değiştirdim
    @objc func goPrevPage() { preziView.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, which: 37}));") }
    @objc func goNextPage() { preziView.evaluateJavaScript("document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, which: 39}));") }
    @objc func goFullScreen() { preziView.evaluateJavaScript("document.querySelector('.present-button')?.click();") }

    @objc func syncFrames() {
        preziView.takeSnapshot(with: nil) { image, _ in
            guard let img = image, let data = img.jpegData(compressionQuality: 0.5) else { return }
            let b64 = data.base64EncodedString()
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(b64)');}")
        }
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle { return .lightContent }
}

// MARK: - Çerez Yönetimi
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        webView.loadDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.writeDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
}

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
                
                // Buradaki 'cookieName' uyarısını '_' yaparak düzelttik
                for (_, cookieConfig) in mergedCookie {
                    let cookie = cookieConfig as! Dictionary<String, Any>
                    var expire : Any? = nil
                    if let expireTime = cookie["Expires"] as? Double { expire = Date(timeIntervalSinceNow: expireTime) }
                    
                    let newCookie = HTTPCookie(properties: [
                        .domain: cookie["Domain"] as Any,
                        .path: cookie["Path"] as Any,
                        .name: cookie["Name"] as Any,
                        .value: cookie["Value"] as Any,
                        .secure: cookie["Secure"] as Any,
                        .expires: expire as Any
                    ])
                    self.configuration.websiteDataStore.httpCookieStore.setCookie(newCookie!)
                }
                completion()
            }
        } else { completion() }
    }
    
    func fetchInMemoryCookies(for domain: String, completion: @escaping ([String: Any]) -> ()) {
        var cookieDict = [String: AnyObject]()
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { (cookies) in
            for cookie in cookies {
                if cookie.domain.contains(domain) {
                    cookieDict[cookie.name] = cookie.properties as AnyObject?
                }
            }
            completion(cookieDict)
        }
    }
}

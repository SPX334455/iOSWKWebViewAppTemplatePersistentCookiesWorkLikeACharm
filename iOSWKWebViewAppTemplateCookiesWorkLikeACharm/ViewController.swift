import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {
    
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    let umingleURL = URL(string: "https://umingle.com")!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        requestNativePermissions()
        setupStatusbar()
        setupWebViews()
        setupControls()
        
        timer = Timer.scheduledTimer(timeInterval: 0.06, target: self, selector: #selector(syncFrames), userInfo: nil, repeats: true)
    }
    
    func requestNativePermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
    
    // 🔁 SADECE BU FONKSİYON DEĞİŞTİ
    func setupWebViews() {
        let hookJS = """
        (function() {
            console.log("Sanal Kamera Başlatılıyor...");
            
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            ctx.fillStyle = "black";
            ctx.fillRect(0,0,1280,720);
            
            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { ctx.drawImage(img, 0, 0, 1280, 720); };
                img.src = 'data:image/jpeg;base64,' + b64;
            };

            function getSilentAudioTrack() {
                var ctx = new (window.AudioContext || window.webkitAudioContext)();
                var oscillator = ctx.createOscillator();
                var dst = ctx.createMediaStreamDestination();
                oscillator.connect(dst);
                oscillator.start();
                return dst.stream.getAudioTracks()[0];
            }

            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([
                    {deviceId:'virtual-cam-id', kind:'videoinput', label:'Apple Front Camera', groupId:'1'},
                    {deviceId:'virtual-mic-id', kind:'audioinput', label:'Apple Microphone', groupId:'1'}
                ]);
            };

            function getFakeStream() {
                var stream = canvas.captureStream(30);
                stream.addTrack(getSilentAudioTrack());
                return stream;
            }

            navigator.mediaDevices.getUserMedia = function(constraints) {
                return Promise.resolve(getFakeStream());
            };

            navigator.webkitGetUserMedia = function(constraints, success, error) {
                success(getFakeStream());
            };

            var originalAddTrack = RTCPeerConnection.prototype.addTrack;
            RTCPeerConnection.prototype.addTrack = function(track, stream) {
                if (track.kind === 'video') {
                    var fakeStream = canvas.captureStream(30);
                    return originalAddTrack.call(this, fakeStream.getVideoTracks()[0], stream);
                }
                return originalAddTrack.call(this, track, stream);
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        let script = WKUserScript(source: hookJS, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.ignoresViewportScaleLimits = true
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
        self.view.addSubview(webView)
        
        let preziConfig = WKWebViewConfiguration()
        preziConfig.allowsInlineMediaPlayback = true
        preziView = WKWebView(frame: .zero, configuration: preziConfig)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderWidth = 2
        preziView.layer.borderColor = UIColor.green.cgColor
        self.view.addSubview(preziView)

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

    @objc func goPrevPage() {
        preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 37, which: 37, bubbles: true}));")
    }
    @objc func goNextPage() {
        preziView.evaluateJavaScript("window.focus(); document.dispatchEvent(new KeyboardEvent('keydown', {keyCode: 39, which: 39, bubbles: true}));")
    }
    @objc func forceStart() {
        preziView.evaluateJavaScript("""
            window.focus();
            var playBtn = document.querySelector('.prezi-player-icon-play');
            if(playBtn) playBtn.click();
            var presentBtn = document.querySelector('.present-button');
            if(presentBtn) presentBtn.click();
        """)
    }

    @objc func syncFrames() {
        if preziView.isLoading { return }
        preziView.takeSnapshot(with: nil) { image, _ in
            guard let img = image,
                  let data = img.jpegData(compressionQuality: 0.4) else { return }
            let b64 = data.base64EncodedString()
            self.webView.evaluateJavaScript("if(window.drawToFakeCamera){window.drawToFakeCamera('\(b64)');}")
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}

// EXTENSIONLAR AYNEN DURUYOR
extension ViewController: WKUIDelegate, WKNavigationDelegate {
    @available(iOS 15.0, *)
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        webView.loadDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.writeDiskCookies(for: umingleURL.host!) { decisionHandler(.allow) }
    }
}

import UIKit
import WebKit
import AVFoundation

class GhostFinalViewController: UIViewController, WKUIDelegate {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var isFakeMode = false 
    private var displayLink: CADisplayLink?
    
    // 🖼️ FOTOĞRAF: Eğer hata devam ederse burayı boş bırakıp dene
    private var myPhotoBase64: String = "" 

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupAudioSession()
        setupInterface()
        setupControls()
        startStreaming()
    }

    func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker])
        try? session.setActive(true)
    }

    func setupInterface() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        // GHOST CORE: Ses ve Görüntü Birleştirme
        let jsSource = """
        (function() {
            const canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            const ctx = canvas.getContext('2d', { alpha: false });
            let lastImg = new Image();

            const stream = canvas.captureStream(20);
            const videoTrack = stream.getVideoTracks()[0];

            // Media Hijack
            const originalGUM = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
            navigator.mediaDevices.getUserMedia = async (c) => {
                const final = new MediaStream();
                if (c.audio) {
                    const audio = await originalGUM({ audio: true, video: false });
                    audio.getAudioTracks().forEach(t => final.addTrack(t));
                }
                final.addTrack(videoTrack);
                return final;
            };

            window.updateGhost = (b64) => {
                lastImg.onload = () => ctx.drawImage(lastImg, 0, 0, 1280, 720);
                lastImg.src = b64;
            };
        })();
        """
        config.userContentController.addUserScript(WKUserScript(source: jsSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.uiDelegate = self
        view.addSubview(webView)
        
        preziView = WKWebView(frame: CGRect(x: -2000, y: 0, width: 1280, height: 720))
        view.addSubview(preziView)
        
        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    func startStreaming() {
        displayLink = CADisplayLink(target: self, selector: #selector(stream))
        displayLink?.preferredFramesPerSecond = 20
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc func stream() {
        autoreleasepool {
            if isFakeMode {
                if !myPhotoBase64.isEmpty {
                    self.webView.evaluateJavaScript("window.updateGhost('\(myPhotoBase64)');")
                }
            } else {
                preziView.takeSnapshot(with: nil) { img, _ in
                    if let d = img?.jpegData(compressionQuality: 0.6) {
                        let b64 = "data:image/jpeg;base64," + d.base64EncodedString()
                        self.webView.evaluateJavaScript("window.updateGhost('\(b64)');")
                    }
                }
            }
        }
    }

    func setupControls() {
        let btn = UIButton(frame: CGRect(x: 20, y: 50, width: 100, height: 40))
        btn.setTitle("MOD", for: .normal); btn.backgroundColor = .systemRed; btn.layer.cornerRadius = 8
        btn.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        view.addSubview(btn)
    }

    @objc func toggle() { isFakeMode.toggle(); (view.subviews.last as? UIButton)?.backgroundColor = isFakeMode ? .blue : .red }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var isFakeMode = false
    private var displayLink: CADisplayLink?
    
    // Dosyadan okunacak Base64 burada tutulacak
    private var finalBase64: String = ""

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscapeLeft }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        loadBase64FromFile() // 1. Önce dosyayı oku
        setupWebViews()     // 2. Webview'ları kur
        setupControls()     // 3. Butonları ekle
        
        // 30 FPS Akış Döngüsü
        displayLink = CADisplayLink(target: self, selector: #selector(syncStream))
        displayLink?.preferredFramesPerSecond = 30
        displayLink?.add(to: .main, forMode: .common)
    }

    // --- 📄 DOSYADAN OKUMA FONKSİYONU ---
    func loadBase64FromFile() {
        if let path = Bundle.main.path(forResource: "foto", ofType: "txt") {
            do {
                let content = try String(contentsOfFile: path, encoding: .utf8)
                // Gereksiz boşlukları temizle ve formatı kontrol et
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                finalBase64 = trimmed.hasPrefix("data") ? trimmed : "data:image/jpeg;base64," + trimmed
                print("✅ Fotoğraf dosyası başarıyla yüklendi.")
            } catch {
                print("❌ Dosya okuma hatası: \(error)")
            }
        } else {
            print("⚠️ foto.txt dosyası projede bulunamadı!")
        }
    }

    func setupWebViews() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        // --- 🚀 PROFESYONEL JS INJECTION ---
        let js = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d', {alpha: false, desynchronized: true});
            
            var currentImg = new Image();
            var hasStarted = false;

            window.sendToCam = function(b64) {
                if(!b64) return;
                currentImg.onload = function() {
                    ctx.drawImage(currentImg, 0, 0, 1280, 720);
                    // ANTI-FREEZE: Görünmez hareketli piksel (Siyah ekran çözümü)
                    ctx.fillStyle = "rgba(0,0,0,0.01)";
                    ctx.fillRect(Math.random(), Math.random(), 1, 1);
                    hasStarted = true;
                };
                currentImg.src = b64;
            };

            // Stream'i oluştur ve hazır tut
            var stream = canvas.captureStream(30);
            navigator.mediaDevices.getUserMedia = function() { return Promise.resolve(stream); };
            
            // Siteyi cihaz olduğuna ikna et
            navigator.mediaDevices.enumerateDevices = function() {
                return Promise.resolve([{ kind: 'videoinput', label: 'FaceTime HD Camera', deviceId: 'default' }]);
            };
        })();
        """
        config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.uiDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"
        view.addSubview(webView)

        // Sunum Ekranı
        preziView = WKWebView(frame: CGRect(x: view.frame.width - 260, y: 20, width: 240, height: 135))
        preziView.layer.borderColor = UIColor.green.cgColor; preziView.layer.borderWidth = 2
        view.addSubview(preziView)

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    @objc func syncStream() {
        autoreleasepool {
            if isFakeMode {
                if !finalBase64.isEmpty {
                    webView.evaluateJavaScript("window.sendToCam('\(finalBase64)');")
                }
            } else {
                preziView.takeSnapshot(with: nil) { img, _ in
                    if let d = img?.jpegData(compressionQuality: 0.8) {
                        let b64 = "data:image/jpeg;base64," + d.base64EncodedString()
                        self.webView.evaluateJavaScript("window.sendToCam('\(b64)');")
                    }
                }
            }
        }
    }

    func setupControls() {
        let btn = UIButton(frame: CGRect(x: view.center.x - 75, y: view.frame.height - 80, width: 150, height: 50))
        btn.setTitle("MOD DEĞİŞTİR", for: .normal); btn.backgroundColor = .systemBlue
        btn.layer.cornerRadius = 15; btn.addTarget(self, action: #selector(toggleMode), for: .touchUpInside)
        view.addSubview(btn)
    }

    @objc func toggleMode() {
        isFakeMode.toggle()
        preziView.isHidden = isFakeMode
    }

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

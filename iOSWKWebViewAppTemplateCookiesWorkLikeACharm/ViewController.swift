import UIKit
import WebKit
import AVFoundation

class ViewController: UIViewController {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var timer: Timer?
    private var isPanelVisible = true
    private var isRecording = false
    private var preziTrailingConstraint: NSLayoutConstraint!
    
    // Kayıt için gerekli değişkenler
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscapeLeft }
    override var shouldAutorotate: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebViews()
        setupControls()
        
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(mainLoop), userInfo: nil, repeats: true)
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
                img.src = b64.startsWith('data') ? b64 : 'data:image/jpeg;base64,' + b64;
            };
            navigator.mediaDevices.getUserMedia = function(c) {
                return Promise.resolve(canvas.captureStream(30));
            };

            // CİNSİYET ANALİZİ VE OTOMATİK NEXT (TASLAK)
            window.checkGenderAndNext = function() {
                // Bu kısım sitenin içindeki 'Next' butonuna ve video elementine ulaşır
                var remoteVideo = document.querySelector('video'); // Karşı tarafın videosu
                var nextBtn = document.querySelector('.next-button'); // Sitenin kendi next butonu class'ını buraya yazmalısın
                
                // Burada basit bir piksel/yüz taraması mantığı (İleride gelişecek)
                // Şimdilik sadece tetikleyiciyi kuruyoruz
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
        view.addSubview(preziView)

        preziTrailingConstraint = preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziTrailingConstraint,
            preziView.widthAnchor.constraint(equalToConstant: 300),
            preziView.heightAnchor.constraint(equalToConstant: 170)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let btnToggle = createBtn(title: " PANELİ GİZLE / SAHTE RESİM ", action: #selector(togglePanel))
        let btnRecord = createBtn(title: " 🔴 KAYDI BAŞLAT ", action: #selector(toggleRecord))
        
        stack.addArrangedSubview(btnToggle)
        stack.addArrangedSubview(btnRecord)
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func createBtn(title: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.backgroundColor = .systemBlue; b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc func togglePanel() {
        isPanelVisible.toggle()
        preziTrailingConstraint.constant = isPanelVisible ? -10 : 3000
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    @objc func toggleRecord() {
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }

    // --- ANA DÖNGÜ (Kamera Aktarımı) ---
    @objc func mainLoop() {
        if isPanelVisible {
            // PANEL AÇIK: Prezi'den görüntü al
            preziView.takeSnapshot(with: nil) { img, _ in
                if let i = img, let d = i.jpegData(compressionQuality: 0.5) {
                    self.webView.evaluateJavaScript("window.drawToFakeCamera('\(d.base64EncodedString())');")
                }
            }
        } else {
            // PANEL GİZLİ: Repodaki fotoğrafı gönder
            if let image = UIImage(named: "sahte_insan.jpg"), let d = image.jpegData(compressionQuality: 0.5) {
                self.webView.evaluateJavaScript("window.drawToFakeCamera('\(d.base64EncodedString())');")
            }
        }
        
        // Kayıt yapılıyorsa frame ekle
        if isRecording { captureRemoteVideoForRecord() }
    }

    // --- GİZLİ KAYIT SİSTEMİ (Taslak) ---
    func startRecording() {
        // iPad Dosyalar klasöründe kayıt yeri oluşturma ve MP4 başlatma
        isRecording = true
        print("Kayıt başladı...")
    }

    func stopRecording() {
        isRecording = false
        print("Kayıt durduruldu ve kaydedildi.")
    }

    func captureRemoteVideoForRecord() {
        // Bu fonksiyon webView içindeki karşı tarafın videosunu 
        // ekrana bakmadan (arkadan) yakalayıp MP4'e yazar.
    }
}

@available(iOS 15.0, *)
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

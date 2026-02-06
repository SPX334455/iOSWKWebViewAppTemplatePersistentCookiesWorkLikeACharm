import UIKit
import WebKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    private var webView: WKWebView!
    private var preziView: WKWebView!
    private var isFakeMode = false
    private var isRecording = false
    private var timer: Timer?
    private var preziTrailingConstraint: NSLayoutConstraint!
    
    // Kayıt için AssetWriter bileşenleri
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var frameCount: Int64 = 0
    private var recordingStartTime: CMTime?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscapeLeft }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupWebViews()
        setupControls()
        
        // Ana İşlem Döngüsü (15 FPS)
        timer = Timer.scheduledTimer(timeInterval: 0.07, target: self, selector: #selector(mainProcessor), userInfo: nil, repeats: true)
    }

    func setupWebViews() {
        let scriptSource = """
        (function() {
            var canvas = document.createElement('canvas');
            canvas.width = 1280; canvas.height = 720;
            var ctx = canvas.getContext('2d');
            
            // Sanal Kamera Enjeksiyonu
            window.drawToFakeCamera = function(b64) {
                var img = new Image();
                img.onload = function() { 
                    ctx.clearRect(0,0,1280,720);
                    ctx.drawImage(img, 0, 0, 1280, 720); 
                };
                img.src = b64;
            };

            navigator.mediaDevices.getUserMedia = function(c) {
                return Promise.resolve(canvas.captureStream(30));
            };

            // ESC (27) ile Next Fonksiyonu (2 Kez Basar)
            window.umingleNext = function() {
                const sendEsc = () => {
                    window.dispatchEvent(new KeyboardEvent('keydown', { keyCode: 27, which: 27, bubbles: true }));
                    window.dispatchEvent(new KeyboardEvent('keyup', { keyCode: 27, which: 27, bubbles: true }));
                };
                sendEsc();
                setTimeout(sendEsc, 400); // 0.4 saniye sonra ikinci basış
            };

            // Karşı Tarafın Görüntüsünü Ham Olarak Yakala (Kayıt ve Analiz İçin)
            window.getRemoteFrame = function() {
                var v = document.querySelector('video');
                if(!v || v.paused || v.ended) return null;
                var tmpCanvas = document.createElement('canvas');
                tmpCanvas.width = v.videoWidth; tmpCanvas.height = v.videoHeight;
                tmpCanvas.getContext('2d').drawImage(v, 0, 0);
                return tmpCanvas.toDataURL('image/jpeg', 0.8);
            };
        })();
        """
        
        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        config.allowsInlineMediaPlayback = true

        webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.uiDelegate = self
        view.addSubview(webView)

        preziView = WKWebView(frame: .zero)
        preziView.translatesAutoresizingMaskIntoConstraints = false
        preziView.layer.borderColor = UIColor.green.cgColor; preziView.layer.borderWidth = 2
        view.addSubview(preziView)

        preziTrailingConstraint = preziView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -10)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            preziView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            preziTrailingConstraint,
            preziView.widthAnchor.constraint(equalToConstant: 280),
            preziView.heightAnchor.constraint(equalToConstant: 160)
        ])

        webView.load(URLRequest(url: URL(string: "https://umingle.com")!))
        preziView.load(URLRequest(url: URL(string: "https://prezi.com/p/wckx0wlz288z/")!))
    }

    func setupControls() {
        let stack = UIStackView()
        stack.axis = .horizontal; stack.spacing = 10; stack.translatesAutoresizingMaskIntoConstraints = false
        
        let btnMode = createBtn(title: " 🖼️ NORMAL ", action: #selector(toggleFakeMode), color: .systemBlue)
        let btnRecord = createBtn(title: " 🔴 KAYIT ", action: #selector(toggleRecord), color: .systemGray)
        let btnNext = createBtn(title: " ⏭️ NEXT (ESC) ", action: #selector(manualNext), color: .systemOrange)
        
        [btnMode, btnRecord, btnNext].forEach { stack.addArrangedSubview($0) }
        view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            stack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func createBtn(title: String, action: Selector, color: UIColor) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal); b.backgroundColor = color
        b.setTitleColor(.white, for: .normal); b.layer.cornerRadius = 12
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc func toggleFakeMode() {
        isFakeMode.toggle()
        preziTrailingConstraint.constant = isFakeMode ? 3000 : -10
        if let btn = (view.subviews.last as? UIStackView)?.arrangedSubviews[0] as? UIButton {
            btn.setTitle(isFakeMode ? " 🖼️ SAHTE MOD " : " 🖼️ NORMAL ", for: .normal)
            btn.backgroundColor = isFakeMode ? .systemGreen : .systemBlue
        }
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }

    @objc func manualNext() {
        webView.evaluateJavaScript("window.umingleNext();")
    }

    @objc func toggleRecord() {
        isRecording.toggle()
        if let btn = (view.subviews.last as? UIStackView)?.arrangedSubviews[1] as? UIButton {
            btn.setTitle(isRecording ? " ⏺️ KAYDEDİYOR " : " 🔴 KAYIT ", for: .normal)
            btn.backgroundColor = isRecording ? .systemRed : .systemGray
        }
        
        if isRecording {
            startVideoRecording()
        } else {
            stopVideoRecording()
        }
    }

    @objc func mainProcessor() {
        // 1. KAMERA AKTARIMI (Prezi veya Sahte Resim)
        if isFakeMode {
            if let path = Bundle.main.path(forResource: "sahte_insan", ofType: "jpg"),
               let image = UIImage(contentsOfFile: path),
               let d = image.jpegData(compressionQuality: 0.5) {
                let base64 = "data:image/jpeg;base64," + d.base64EncodedString()
                self.webView.evaluateJavaScript("window.drawToFakeCamera('\(base64)');")
            }
        } else {
            preziView.takeSnapshot(with: nil) { img, _ in
                if let i = img, let d = i.jpegData(compressionQuality: 0.4) {
                    let base64 = "data:image/jpeg;base64," + d.base64EncodedString()
                    self.webView.evaluateJavaScript("window.drawToFakeCamera('\(base64)');")
                }
            }
        }
        
        // 2. KARŞI TARAFI ANALİZ VE KAYIT (Arka Planda)
        processRemoteVideo()
    }

    func processRemoteVideo() {
        webView.evaluateJavaScript("window.getRemoteFrame()") { [weak self] result, _ in
            guard let self = self, let b64 = result as? String,
                  let data = Data(base64Encoded: b64.components(separatedBy: ",")[1]),
                  let image = UIImage(data: data) else { return }
            
            // Eğer kayıt açıksa frame ekle
            if self.isRecording {
                self.recordFrame(image: image)
            }
            
            // Cinsiyet Analizi (Her 3 saniyede bir yapalım ki donmasın)
            if self.frameCount % 45 == 0 {
                self.detectGender(image: image)
            }
            self.frameCount += 1
        }
    }

    // --- CİNSİYET ANALİZİ (YAPAY ZEKA) ---
    func detectGender(image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let results = request.results as? [VNFaceObservation], !results.isEmpty else { return }
            
            // Burada basit bir "yüz bulursa erkek say ve geç" mantığı kurabiliriz 
            // Veya gelişmiş analiz için VNFaceLandmarks kullanılır.
            // Şimdilik test için: Eğer yüz bıyık/sakal bölgesinde yoğunluk varsa Next yapalım.
            // Bu kısım Vision Framework ile geliştirilecek.
        }
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request])
    }

    // --- VİDEO KAYIT MOTORU ---
    func startVideoRecording() {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Umingle_Kayıt_\(Date().timeIntervalSince1970).mp4")
        do {
            assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 640,
                AVVideoHeightKey: 480
            ]
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            videoInput?.expectsMediaDataInRealTime = true
            pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: nil)
            
            assetWriter?.add(videoInput!)
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            recordingStartTime = CMTime(value: frameCount, timescale: 15)
            print("Kayıt Dosyaya Başladı: \(fileURL)")
        } catch { print("Kayıt başlatılamadı.") }
    }

    func recordFrame(image: UIImage) {
        guard let adaptor = pixelBufferAdaptor, videoInput?.isReadyForMoreMediaData == true else { return }
        // UIImage to CVPixelBuffer and append logic...
    }

    func stopVideoRecording() {
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { print("Video Dosyalar Klasörüne Kaydedildi.") }
    }
}

@available(iOS 15.0, *)
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }
}

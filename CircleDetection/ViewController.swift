import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var roundnessLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var binaryThresholdLabel: UILabel!
    @IBOutlet weak var binaryThresholdSlider: UISlider!
    @IBOutlet weak var roundnessThresholdLabel: UILabel!
    @IBOutlet weak var roundnessThresholdSlider: UISlider!
    
    private var binaryThreshold: Float = 0.0 {
        didSet {
            binaryThresholdLabel.text = binaryThreshold.dot3f
            circleDetector.binaryThreshold = binaryThreshold
        }
    }
    
    private var roundnessThreshold: Float = 0.0 {
        didSet {
            roundnessThresholdLabel.text = roundnessThreshold.dot3f
        }
    }

    private let ciContext = CIContext(options: [
        .cacheIntermediates : false,
        .name : "ViewControllerCIContext"
    ])
    
    private lazy var imageCapture = ImageCapture()
    private lazy var circleDetector = CircleDetector()
    private var contourPathLayers: [CAShapeLayer] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        binaryThreshold = 0.2
        roundnessThreshold = 0.8
        roundnessLabel.text = ""
        
        // キャプチャ開始
        imageCapture.delegate = self
        imageCapture.session.startRunning()

        // ライトON
        imageCapture.setTouch(level: 1.0)
    }
    
    @IBAction func binaryThresholdDidChange(_ sender: UISlider) {
        binaryThreshold = sender.value
    }
    
    @IBAction func roundnessThresholdDidChange(_ sender: UISlider) {
        roundnessThreshold = sender.value
    }
}

// MARK: - ImageCaptureDelegate

extension ViewController: ImageCaptureDelegate {
    func captureOutput(ciImage: CIImage) {
        // 右回転して向きを縦に直す
        let rotatedImage = ciImage.oriented(.right)

        // 円を検出
        guard let result = circleDetector.perform(ciImage: rotatedImage) else { return }
        
        let detectSize = circleDetector.detectSize
        let cropRect = CGRect(x: 0,
                              y: rotatedImage.extent.height/2 - detectSize/2,
                              width: detectSize,
                              height: detectSize)
        let inputImage = rotatedImage.cropped(to: cropRect)
        
        // 入力画像を生成
        guard let outputImage = ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            return
        }
        
        DispatchQueue.main.async {
            if result.circles.count == 1 {
                self.roundnessLabel.text = result.circles[0].roundness.dot3f
            } else {
                self.roundnessLabel.text = ""
            }
            self.imageView.image = UIImage(cgImage: outputImage)
            self.drawCirclePath(result.circles)
        }
    }
}

// MARK: - 輪郭描画

private extension ViewController {
    private func drawCirclePath(_ circles: [DetectedCircles.Circle]) {
        // 表示中のパスは消す
        contourPathLayers.forEach {
            $0.removeFromSuperlayer()
        }

        let detectFrame = CGRect(x: 0,
                                 y: imageView.frame.height / 2.0 - imageView.frame.width / 2.0,
                                 width: imageView.frame.width,
                                 height: imageView.frame.width)
        circles.forEach {
            guard let cgPath = $0.cgPath.transform(to: detectFrame.width) else { return }
            
            let pathLayer = CAShapeLayer()
            pathLayer.frame = detectFrame
            pathLayer.path = cgPath
            // 円形度でパスの色を変える
            pathLayer.strokeColor =  $0.roundness > roundnessThreshold ? UIColor.blue.cgColor : UIColor.red.cgColor
            pathLayer.lineWidth = 4
            pathLayer.fillColor = UIColor.clear.cgColor
            imageView.layer.addSublayer(pathLayer)
            contourPathLayers.append(pathLayer)
        }
    }
}

extension CGPath {
    /// 0~1に正規化された座標をUIKitの座標に変換
    /// - Parameter to: Viewの一辺のサイズ
    /// - Returns: UIKitの座標系に変換されたパス
    func transform(to: CGFloat) -> CGPath? {
        var transform = CGAffineTransform(scaleX: to, y: -to)
        transform = transform.concatenating(CGAffineTransform(translationX: 0, y: to))
        return self.copy(using: &transform)
    }
}

extension Float {
    var dot3f: String {
        String(format: "%.3f", self)
    }
}

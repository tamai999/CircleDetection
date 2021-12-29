import UIKit
import Accelerate

fileprivate struct Const {
    // 異常判定の閾値（マハラノビス距離）
    static let mdThreshold: Float = 3.0
    // グラフ設定
    static let graphSize = 200
    static let roundnessScale: Float = 1.0
    static let areaScale: Float = 0.006
}

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var graphView: UIImageView!
    
    private let ciContext = CIContext(options: [
        .cacheIntermediates : false,
        .name : "ViewControllerCIContext"
    ])
    
    private lazy var imageCapture = ImageCapture()
    private lazy var circleDetector = CircleDetector()
    private var contourPathLayers: [CAShapeLayer] = []
    
    private let egomaClass = MDClass(meanX: 0.858361357,
                                     meanY: 0.000974214,
                                     stdDeviationX: 0.197776171,
                                     stdDeviationY: 0.000189814,
                                     covarianceXY: 0.000018802)
    
    private let sobaClass = MDClass(meanX: 0.814706310,
                                    meanY: 0.003867940,
                                    stdDeviationX: 0.070025460,
                                    stdDeviationY: 0.000603650,
                                    covarianceXY: 0.000000648)
    // グラフデータ
    private lazy var canvas = SimpleCanvas(width: Const.graphSize,
                                           height: Const.graphSize,
                                           scaleX: Const.areaScale,
                                           scaleY: Const.roundnessScale)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // グラフの静的部分を表示
        asyncDrawBase() {
            // キャプチャ開始
            self.imageCapture.delegate = self
            self.imageCapture.session.startRunning()
            // ライトON
            self.imageCapture.setTouch(level: 1.0)
        }
        
        // 二値化閾値
        circleDetector.binaryThreshold = 0.3
    }
}

// MARK: - ImageCaptureDelegate

extension ViewController: ImageCaptureDelegate {
    func captureOutput(ciImage: CIImage) {
        // 右回転して向きを縦に直す
        let rotatedImage = ciImage.oriented(.right)
        
        // 円を検出
        guard let result = circleDetector.perform(ciImage: rotatedImage) else { return }
        // クラス識別
        let classified: [(path: CGPath, area: Float, roundness: Float, color: UIColor)] = result.circles.map {
            let color = classify(roundness: $0.roundness, area: $0.area)
            return ($0.cgPath, area: $0.area, $0.roundness, color)
        }
        
        // 表示用画像を生成
        let detectSize = circleDetector.detectSize
        let cropRect = CGRect(x: 0,
                              y: rotatedImage.extent.height/2 - detectSize/2,
                              width: detectSize,
                              height: detectSize)
        let inputImage = rotatedImage.cropped(to: cropRect)
        guard let outputImage = ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            return
        }
        
        DispatchQueue.main.async {
            self.imageView.image = UIImage(cgImage: outputImage)
            // ビデオ画像に輪郭を重ねる
            self.drawCirclePath(classified)
            // グラフ表示
            self.canvas.restore()
            classified.forEach { _, area, roundness, color in
                self.canvas.drawRect(posX: area, posY: roundness, color: color, size: .large)
            }
            if let image = self.canvas.image {
                self.graphView.image = UIImage(cgImage: image)
            }
        }
    }
}

// MARK: - 分類

private extension ViewController {
    func classify(roundness: Float, area: Float) -> UIColor {
        let mdEgoma = egomaClass.mahalanobisDistance(x: roundness, y: area)
        let mdSoba = sobaClass.mahalanobisDistance(x: roundness, y: area)
        
        guard let mdEgoma = mdEgoma, let mdSoba = mdSoba else { return .clear }

        let color: UIColor
        if mdEgoma > Const.mdThreshold, mdSoba > Const.mdThreshold {
            // 外れ値
            color = .red
        } else if mdEgoma > mdSoba {
            // 蕎麦
            color = .green
        } else {
            // エゴマ
            color = .blue
        }
        return color
    }
}

// MARK: - 輪郭描画

private extension ViewController {
    private func drawCirclePath(_ classified: [(path: CGPath, area: Float, roundness: Float, color: UIColor)]) {
        // 表示中のパスは消す
        contourPathLayers.forEach {
            $0.removeFromSuperlayer()
        }
        
        let detectFrame = CGRect(x: 0,
                                 y: imageView.frame.height / 2.0 - imageView.frame.width / 2.0,
                                 width: imageView.frame.width,
                                 height: imageView.frame.width)
        classified.forEach {
            guard let cgPath = $0.path.transform(to: detectFrame.width) else { return }
            
            let pathLayer = CAShapeLayer()
            pathLayer.frame = detectFrame
            pathLayer.path = cgPath
            pathLayer.strokeColor = $0.color.cgColor
            pathLayer.lineWidth = 4
            pathLayer.fillColor = UIColor.clear.cgColor
            imageView.layer.addSublayer(pathLayer)
            contourPathLayers.append(pathLayer)
        }
    }
}

// - MARK: グラフ表示

private extension ViewController {
    func asyncDrawBase(completion: @escaping (() -> ())) {
        DispatchQueue.global().async {
            self.drawBase {
                completion()
            }
        }
    }
    
    func drawBase(completion: (() -> ())) {
        // 各クラスについてグラフの全画素分のマハラノビス距離を計算（等距離線描画用）
        var egomaMDs: [Float] = []
        var sobaMDs: [Float] = []
        for xIndex in 0..<Const.graphSize {
            for yIndex in 0..<Const.graphSize {
                let featureX = Float(Const.graphSize - xIndex - 1) * Const.roundnessScale / Float(Const.graphSize)
                let featureY = Float(yIndex) * Const.areaScale / Float(Const.graphSize)
                
                let egomaMd = egomaClass.mahalanobisDistance(x: featureX, y: featureY) ?? 0.0
                let sobaMd = sobaClass.mahalanobisDistance(x: featureX, y: featureY) ?? 0.0
                egomaMDs.append(egomaMd)
                sobaMDs.append(sobaMd)
            }
        }
        
        // 枠線
        canvas.guideLine(numberX: 6, numberY: 10, color: .darkGray)
        canvas.frameColor = .white
        
        // 学習用データ
        SampleData.egoma.forEach { (area, roundness) in
            canvas.drawRect(posX: area, posY: roundness, color: .magenta, size: .small)
        }
        
        SampleData.soba.forEach { (area, roundness) in
            canvas.drawRect(posX: area, posY: roundness, color: .magenta, size: .small)
        }
        
        // マハラノビス等距離線
        let boundaries: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        canvas.drawContour(data: egomaMDs, boundaries: boundaries, color: .lightGray)
        canvas.drawContour(data: sobaMDs, boundaries: boundaries, color: .lightGray)
        
        canvas.save()
        
        DispatchQueue.main.async {
            if let image = self.canvas.image {
                self.graphView.image = UIImage(cgImage: image)
            }
        }
        
        completion()
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

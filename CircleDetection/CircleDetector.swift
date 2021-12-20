import UIKit
import Vision
import CoreImage.CIFilterBuiltins

fileprivate struct Const {
    static let morphologyClosingRadius: Float = 2
    static let morphologyOpeningRadius: Float = 2
    
    static let grayScaleVector = CIVector(x: 0.298912, y: 0.586611, z:0.114478, w: 0)
    
    static let unSharpMaskRadius: Float = 5.0
    static let unSharpMaskIntensity: Float = 2.0
}

/// 検出結果
struct DetectedCircles {
    struct Circle {
        // 円のパス
        var cgPath: CGPath
        // 円形度
        var roundness: Float
        // 面積
        var area: Float
        // 周囲長
        var perimeter: Float
    }
    
    // 検出用前処理画像
    var image: CIImage
    // 検出結果
    var circles: [Circle]
}

/// 円の検出器
class CircleDetector {
    private let thresholdFilter = CIFilter.colorThreshold()
    private let unSharpMaskFilter = CIFilter.unsharpMask()
    private let morphologyErodeFilter = CIFilter.morphologyMinimum()
    private let morphologyDilateFilter = CIFilter.morphologyMaximum()
    private let colorMatrixFilter = CIFilter.colorMatrix()
    
    private let ciContext = CIContext(options: [
        .cacheIntermediates : false,
        .name : "CircleDetectorCIContext"
    ])
    
    /// 検出ピクセルサイズ（一辺）
    private(set) var detectSize: CGFloat = 0
    
    /// 二値化閾値
    var binaryThreshold: Float = 0.0
    
    /// 円を検出する
    /// - Parameter ciImage: 入力画像
    /// - Returns: 検出結果
    func perform(ciImage: CIImage) -> DetectedCircles? {
        // 検出箇所は中央正方形
        detectSize = min(ciImage.extent.width, ciImage.extent.height)
        
        // 輪郭検出
        guard let processedImage = preprocess(ciImage: ciImage) else { return nil }
        let contours = getContours(ciImage: processedImage)
        
        // 円形度計算
        var circles: [DetectedCircles.Circle] = []
        contours.forEach { contour in
            let result = calcRoundness(contour: contour)
            circles.append(.init(cgPath: contour.normalizedPath,
                                 roundness: result.roundness,
                                 area: result.area,
                                 perimeter: result.perimeter))
        }
        
        return .init(image: processedImage, circles: circles)
    }
}

// MARK: - 輪郭検出

private extension CircleDetector {
    // 輪郭検出しやすいように画像の前加工
    func preprocess(ciImage: CIImage) -> CIImage? {
        // グレースケール化
        colorMatrixFilter.inputImage = ciImage
        colorMatrixFilter.rVector = Const.grayScaleVector
        colorMatrixFilter.gVector = Const.grayScaleVector
        colorMatrixFilter.bVector = Const.grayScaleVector
        colorMatrixFilter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        guard let grayScaleImage = colorMatrixFilter.outputImage else { return nil }
        
        // 鮮鋭化
        unSharpMaskFilter.inputImage = grayScaleImage
        unSharpMaskFilter.radius = Const.unSharpMaskRadius
        unSharpMaskFilter.intensity = Const.unSharpMaskIntensity
        guard let unSharpMaskImage = unSharpMaskFilter.outputImage else { return nil }
        
        // 二値化
        thresholdFilter.inputImage = unSharpMaskImage
        thresholdFilter.threshold = binaryThreshold
        guard let binaryImage = thresholdFilter.outputImage else { return nil }
        
        // 収縮・膨張処理（クロージング）
        morphologyErodeFilter.inputImage = binaryImage
        morphologyErodeFilter.radius = Const.morphologyOpeningRadius
        guard let erodeImage = morphologyErodeFilter.outputImage else { return nil }
        
        morphologyDilateFilter.inputImage = erodeImage
        morphologyDilateFilter.radius = Const.morphologyOpeningRadius
        guard let closingImage = morphologyDilateFilter.outputImage else { return nil }
        
        // 膨張・収縮処理（オープニング）
        morphologyDilateFilter.inputImage = closingImage
        morphologyDilateFilter.radius = Const.morphologyClosingRadius
        guard let dilateImage = morphologyDilateFilter.outputImage else { return nil }
        
        morphologyErodeFilter.inputImage = dilateImage
        morphologyErodeFilter.radius = Const.morphologyClosingRadius
        guard let openingImage = morphologyErodeFilter.outputImage else { return nil }
        
        // 画像中央の正方形を切り取る
        let cropRect = CGRect(x: ciImage.extent.width/2 - detectSize/2,
                              y: ciImage.extent.height/2 - detectSize/2,
                              width: detectSize,
                              height: detectSize)
        
        return openingImage.cropped(to: cropRect)
    }
    
    // 輪郭検出
    private func getContours(ciImage: CIImage) -> [VNContour] {
        let contourRequest = VNDetectContoursRequest.init()
        contourRequest.maximumImageDimension = Int(detectSize)
        contourRequest.detectsDarkOnLight = true
        
        try? VNImageRequestHandler(ciImage: ciImage)
            .perform([contourRequest])
        // 検出結果取得
        guard let observation = contourRequest.results?.first else { return [] }
        // 外側の輪郭だけ返す
        return observation.topLevelContours
    }
}

// MARK: - 円形度計算

extension CircleDetector {
    private func calcRoundness(contour: VNContour) -> (area: Float, perimeter: Float, roundness: Float) {
        do {
            // 面積
            var area: Double = 0.0
            try VNGeometryUtils.calculateArea(&area, for: contour, orientedArea: false)
            
            // 周囲長
            var perimeter: Double = 0.0
            try VNGeometryUtils.calculatePerimeter(&perimeter, for: contour)
            
            // 円形度
            var roundness: Double = 0.0
            if perimeter != 0.0 {
                roundness = (4.0 * .pi * area) / (perimeter * perimeter)
            }
            
            return (Float(area), Float(perimeter), Float(roundness))
            
        } catch {
            return (0.0, 0.0, 0.0)
        }
    }
}

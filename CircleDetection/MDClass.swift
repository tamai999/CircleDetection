import Foundation

/// 2変量クラス
class MDClass {
    /// 特徴x 平均
    var meanX: Float
    /// 特徴y 平均
    var meanY: Float
    /// 特徴x 標準偏差
    var stdDeviationX: Float
    /// 特徴y 標準偏差
    var stdDeviationY: Float
    /// 特徴xy共分散
    var covarianceXY: Float
    /// 相関係数
    var rho: Float? {
        guard stdDeviationX != 0, stdDeviationY != 0 else { return nil }
        return covarianceXY / (stdDeviationX * stdDeviationY)
    }
    
    internal init(meanX: Float, meanY: Float, stdDeviationX: Float, stdDeviationY: Float, covarianceXY: Float) {
        self.meanX = meanX
        self.meanY = meanY
        self.stdDeviationX = stdDeviationX
        self.stdDeviationY = stdDeviationY
        self.covarianceXY = covarianceXY
    }
    
    /// マハラノビス距離計算
    /// - Parameters:
    ///   - x: 特徴x テストデータ
    ///   - y: 特徴y テストデータ
    func mahalanobisDistance(x: Float, y: Float) -> Float? {
        guard stdDeviationX != 0, stdDeviationY != 0, let rho = rho else {
            return nil
        }
        
        let pX = pow((x - meanX), 2) / pow(stdDeviationX, 2)
        let pY = pow((y - meanY), 2) / pow(stdDeviationY, 2)
        let xy2rho = (2.0 * rho * (x - meanX) * (y - meanY)) / (stdDeviationX * stdDeviationY)
        return sqrtf((pX - xy2rho + pY) / (1 - pow(rho, 2)))
    }
}

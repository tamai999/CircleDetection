import AVFoundation
import UIKit

protocol ImageCaptureDelegate {
    func captureOutput(ciImage: CIImage)
}

class ImageCapture: NSObject {
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput",
                                                     qos: .userInitiated,
                                                     attributes: [],
                                                     autoreleaseFrequency: .workItem)
    private var captureDevice: AVCaptureDeviceInput?
    private(set) var session = AVCaptureSession()
    
    // キャプチャー画像の通知用デリゲート
    var delegate: ImageCaptureDelegate?
    
    override init() {
        super.init()
        
        setupAVCapture()
    }
    
    func setTouch(level: Float){
        guard let device = captureDevice?.device, device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if level <= 0.0 {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: min(level, 1.0))
            }
            
            device.unlockForConfiguration()
        } catch {
            print("トーチを設定できませんでした 要求レベル[\(level)]")
        }
    }
    
    private func setupAVCapture() {
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                           mediaType: .video,
                                                           position: .back).devices.first
        guard let deviceInput = try? AVCaptureDeviceInput(device: videoDevice!) else { return }
        captureDevice = deviceInput
        // capture セッション セットアップ
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080
        
        // 入力デバイス指定
        session.addInput(deviceInput)
        
        // 出力先の設定
        session.addOutput(videoDataOutput)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        let captureConnection = videoDataOutput.connection(with: .video)
        captureConnection?.isEnabled = true
        
        session.commitConfiguration()
    }
}

extension ImageCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pb)
        delegate?.captureOutput(ciImage: ciImage)
    }
}

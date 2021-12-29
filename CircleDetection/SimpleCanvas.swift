import UIKit
import Accelerate

class SimpleCanvas {
    enum RectSize: Int {
        case small = 2
        case large = 8
    }
    
    let channel = 3
    let width: Int
    let height: Int
    let scaleX: Float
    let scaleY: Float
    
    private(set) var pixels: [UInt8]
    private var savedPixels: [UInt8]
    
    var image: CGImage? {
        let rgbImage: CGImage? = pixels.withUnsafeMutableBufferPointer { pixelPointer in
            let buffer = vImage_Buffer(data: pixelPointer.baseAddress!,
                                       height: vImagePixelCount(height),
                                       width: vImagePixelCount(width),
                                       rowBytes: Int(width) * channel)
            guard let format = vImage_CGImageFormat(bitsPerComponent: 8,
                                                    bitsPerPixel: 8 * channel,
                                                    colorSpace: CGColorSpaceCreateDeviceRGB(),
                                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue | CGImageByteOrderInfo.orderDefault.rawValue)) else {
                return nil
            }
            return try? buffer.createCGImage(format: format)
        }
        return rgbImage
    }
    
    var frameColor: UIColor = .clear {
        didSet {
            let colorPixel = colorPixel(color: frameColor)
            
            [0, height - 1].forEach { y in
                for x in 0 ..< width {
                    setColor(x: x, y: y, color: colorPixel)
                }
            }
            
            [0, width - 1].forEach { x in
                for y in 1 ..< (height - 1) {
                    setColor(x: x, y: y, color: colorPixel)
                }
            }
        }
    }
    
    init(width: Int, height: Int, scaleX: Float, scaleY: Float) {
        pixels = Array(repeating: 0, count: width * height * channel)
        savedPixels = pixels
        self.width = width
        self.height = height
        self.scaleX = scaleX
        self.scaleY = scaleY
    }

    func save() {
        savedPixels = Array(pixels)
    }
    
    func restore() {
        pixels = Array(savedPixels)
    }
    
    func guideLine(numberX: Int, numberY: Int, color: UIColor) {
        let colorPixel = colorPixel(color: color)
        
        for yStep in 0..<numberY {
            let y = height - Int(floor(Float(yStep) / Float(numberY) * Float(height))) - 1
            for x in 0 ..< width {
                setColor(x: x, y: y, color: colorPixel)
            }
        }
        
        for y in 0..<height {
            for xStep in 0..<numberX {
                let x = Int(floor(Float(xStep) / Float(numberX) * Float(width)))
                setColor(x: x, y: y, color: colorPixel)
            }
        }
    }
    
    func drawContour(data: [Float], boundaries: [Float], color: UIColor) {
        let colorPixel = colorPixel(color: color)
        
        for y in 1 ..< height {
            for x in 1 ..< width {
                let coord = y * width + x
                let val = data[coord]
                let leftVal = data[coord - 1]
                let upVal = data[coord - width]
                
                boundaries.forEach { boundary in
                    if leftVal < boundary && val >= boundary
                        || leftVal >= boundary && val < boundary
                        || upVal < boundary && val >= boundary
                        || upVal >= boundary && val < boundary {
                        
                        setColor(x: x, y: y, color: colorPixel)
                    }
                }
            }
        }
    }
    
    func drawRect(posX: Float, posY: Float, color: UIColor, size: RectSize) {
        let x = Int(posX * (Float(width) / scaleX))
        let y = Int((scaleY - posY) * (Float(height) / scaleY))
        
        drawRect(posX: x, posY: y, size: size.rawValue, color: color)
    }
    
    private func drawRect(posX: Int, posY: Int, size: Int, color: UIColor) {
        let colorPixel = colorPixel(color: color)
        
        let halfSize = size / 2
        let top = posY - halfSize
        let left = posX - halfSize
        
        for y in top ..< top + size where (y >= 0 && y < height) {
            for x in left ..< left + size where (x >= 0 && x < width) {
                setColor(x: x, y: y, color: colorPixel)
            }
        }
    }
    
    private func setColor(x: Int, y: Int, color: (r: UInt8, g: UInt8, b: UInt8)) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let coord = (y * width + x) * channel
        pixels[coord] = color.r
        pixels[coord + 1] = color.g
        pixels[coord + 2] = color.b
    }
    
    private func colorPixel(color :UIColor) -> (r: UInt8, g: UInt8, b: UInt8) {
        let colorPixel: (UInt8, UInt8, UInt8) = {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: nil)
            red = min(red, 1.0)
            green = min(green, 1.0)
            blue = min(blue, 1.0)
            return (UInt8(red * 255), UInt8(green * 255), UInt8(blue * 255))
        }()
        return colorPixel
    }
}

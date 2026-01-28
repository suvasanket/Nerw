import Cocoa

extension NSColor {
    public convenience init?(hexString: String) {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat

        let start =
            hexString.hasPrefix("#")
            ? hexString.index(hexString.startIndex, offsetBy: 1) : hexString.startIndex
        let hexColor = String(hexString[start...])

        if hexColor.count == 6 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
                g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
                b = CGFloat(hexNumber & 0x0000ff) / 255
                a = 1.0

                self.init(srgbRed: r, green: g, blue: b, alpha: a)
                return
            }
        } else if hexColor.count == 8 {
            let scanner = Scanner(string: hexColor)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                r = CGFloat((hexNumber & 0xff00_0000) >> 24) / 255
                g = CGFloat((hexNumber & 0x00ff_0000) >> 16) / 255
                b = CGFloat((hexNumber & 0x0000_ff00) >> 8) / 255
                a = CGFloat(hexNumber & 0x0000_00ff) / 255

                self.init(srgbRed: r, green: g, blue: b, alpha: a)
                return
            }
        }

        return nil
    }

    public func toHexString() -> String {
        guard let rgbColor = self.usingColorSpace(.sRGB) else {
            return "#FFFFFF"
        }

        let r = Int(round(rgbColor.redComponent * 255))
        let g = Int(round(rgbColor.greenComponent * 255))
        let b = Int(round(rgbColor.blueComponent * 255))
        let a = Int(round(rgbColor.alphaComponent * 255))

        if a == 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }
}

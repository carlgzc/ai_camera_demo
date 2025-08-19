// FileName: UIImage+Extensions.swift
import SwiftUI

extension UIImage {
    func resized(withTargetWidth width: CGFloat) -> UIImage? {
        let aspectRatio = self.size.height / self.size.width
        let newSize = CGSize(width: width, height: width * aspectRatio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    func flippedHorizontally() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        context.translateBy(x: self.size.width, y: 0)
        context.scaleBy(x: -1.0, y: 1.0)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }

}

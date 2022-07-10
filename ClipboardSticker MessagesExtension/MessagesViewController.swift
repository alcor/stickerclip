//
//  MessagesViewController.swift
//  ClipboardSticker MessagesExtension
//
//  Created by Nicholas Jitkoff on 7/8/22.
//

import UIKit
import Messages


extension UIImage {
  func resized(to size: CGSize) -> UIImage {
    return UIGraphicsImageRenderer(size: size).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
  func withShadow(blur: CGFloat = 6, offset: CGSize = .zero, color: UIColor = UIColor(white: 0, alpha: 0.8)) -> UIImage {
    
    let shadowRect = CGRect(
      x: offset.width - blur,
      y: offset.height - blur,
      width: size.width + blur * 2,
      height: size.height + blur * 2
    )
    
    UIGraphicsBeginImageContextWithOptions(
      CGSize(
        width: max(shadowRect.maxX, size.width) - min(shadowRect.minX, 0),
        height: max(shadowRect.maxY, size.height) - min(shadowRect.minY, 0)
      ),
      false, 0
    )
    
    let context = UIGraphicsGetCurrentContext()!
    
    context.setShadow(
      offset: offset,
      blur: blur,
      color: color.cgColor
    )
    
    draw(
      in: CGRect(
        x: max(0, -shadowRect.origin.x),
        y: max(0, -shadowRect.origin.y),
        width: size.width,
        height: size.height
      )
    )
    let image = UIGraphicsGetImageFromCurrentImageContext()!
    
    UIGraphicsEndImageContext()
    return image
    }

    /**
    Returns the flat colorized version of the image, or self when something was wrong

    - Parameters:
        - color: The colors to user. By defaut, uses the ``UIColor.white`

    - Returns: the flat colorized version of the image, or the self if something was wrong
    */
    func colorized(with color: UIColor = .white) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)

        defer {
            UIGraphicsEndImageContext()
        }

        guard let context = UIGraphicsGetCurrentContext(), let cgImage = cgImage else { return self }


        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)

        color.setFill()
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.clip(to: rect, mask: cgImage)
        context.fill(rect)

        guard let colored = UIGraphicsGetImageFromCurrentImageContext() else { return self }

        return colored
    }

    /**
    Returns the stroked version of the fransparent image with the given stroke color and the thickness.

    - Parameters:
        - color: The colors to user. By defaut, uses the ``UIColor.white`
        - thickness: the thickness of the border. Default to `2`
        - quality: The number of degrees (out of 360): the smaller the best, but the slower. Defaults to `10`.

    - Returns: the stroked version of the image, or self if something was wrong
    */

    func stroked(with color: UIColor = .white, thickness: CGFloat = 2, quality: CGFloat = 10) -> UIImage {

        guard let cgImage = cgImage else { return self }

        // Colorize the stroke image to reflect border color
        let strokeImage = colorized(with: color)

        guard let strokeCGImage = strokeImage.cgImage else { return self }

        /// Rendering quality of the stroke
        let step = quality == 0 ? 10 : abs(quality)

        let oldRect = CGRect(x: thickness, y: thickness, width: size.width, height: size.height).integral
        let newSize = CGSize(width: size.width + 2 * thickness, height: size.height + 2 * thickness)
        let translationVector = CGPoint(x: thickness, y: 0)


        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)

        guard let context = UIGraphicsGetCurrentContext() else { return self }

        defer {
            UIGraphicsEndImageContext()
        }
        context.translateBy(x: 0, y: newSize.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.interpolationQuality = .high

        for angle: CGFloat in stride(from: 0, to: 360, by: step) {
            let vector = translationVector.rotated(around: .zero, byDegrees: angle)
            let transform = CGAffineTransform(translationX: vector.x, y: vector.y)

            context.concatenate(transform)

            context.draw(strokeCGImage, in: oldRect)

            let resetTransform = CGAffineTransform(translationX: -vector.x, y: -vector.y)
            context.concatenate(resetTransform)
        }

        context.draw(cgImage, in: oldRect)

        guard let stroked = UIGraphicsGetImageFromCurrentImageContext() else { return self }

        return stroked
    }
}


extension CGPoint {
    /**
    Rotates the point from the center `origin` by `byDegrees` degrees along the Z axis.

    - Parameters:
        - origin: The center of he rotation;
        - byDegrees: Amount of degrees to rotate around the Z axis.

    - Returns: The rotated point.
    */
    func rotated(around origin: CGPoint, byDegrees: CGFloat) -> CGPoint {
        let dx = x - origin.x
        let dy = y - origin.y
        let radius = sqrt(dx * dx + dy * dy)
        let azimuth = atan2(dy, dx) // in radians
        let newAzimuth = azimuth + byDegrees * .pi / 180.0 // to radians
        let x = origin.x + radius * cos(newAzimuth)
        let y = origin.y + radius * sin(newAzimuth)
        return CGPoint(x: x, y: y)
    }
}

class MessagesViewController: MSMessagesAppViewController {
  @IBOutlet weak var stickerView: MSStickerView!
  @IBOutlet weak var infoLabel: UILabel!
  var showBorder = false;
  
  func updateUI() {
    
    let pb = UIPasteboard.general;
    print("Pasteboard types:", pb.types)
    
    guard var content = UIPasteboard.general.image else {
      infoLabel.isHidden = false;
      stickerView.isHidden = true;
      return
    }
    
    let maxSize: CGFloat = 512
    
    
    var scale = max(content.size.width, content.size.height) / maxSize;
    
    if (scale > 1.0) {
      content = content.resized(to: CGSize(width:content.size.width / scale, height:content.size.height / scale))
    }
    
    
    if (showBorder) {
      let distance = min(content.size.width, content.size.height) / 20;
      content = content.stroked(with: .white, thickness: distance, quality: 10)
      content = content.withShadow(blur: distance, offset: .init(width: 0, height: distance / 1.5), color: .init(white: 0.2, alpha: 0.333))
    }
    
    let bytes = content.pngData()!.count;
    if (bytes > 500000) {
      scale = scale * 2;
      content = content.resized(to: CGSize(width:content.size.width / scale, height:content.size.height / scale))
    }
    
    let file = createFile(image: content)
    let sticker = try? MSSticker(contentsOfFileURL: file, localizedDescription: "Pasted Sticker");
    
    if ((sticker) != nil) {
      stickerView.sticker = sticker
      stickerView.isHidden = false;
      infoLabel.isHidden = true;
    }
  }
  override func willBecomeActive(with conversation: MSConversation) {
    updateUI()
  }
  
  
  
  func createFile(image: UIImage) -> URL {
    //check if all image dimensions
    //    let isImageDimensionValid = { (_ dimension:CGFloat)->Bool in return dimension >= 300 && dimension <= 618 }
    
    let cacheURL: URL
    let fileManager = FileManager.default
    let directoryName = UUID().uuidString
    let tempPath = NSTemporaryDirectory()
    
    cacheURL = URL(fileURLWithPath: tempPath).appendingPathComponent(directoryName)
    do { try fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil) } catch { fatalError("Unable to create cache URL: \(error)") }
    
    let fileName = "image.png";
    //    print("Length", image.jpegData(compressionQuality: 0.8)?.count ?? "?")
    let url = cacheURL.appendingPathComponent(fileName)
    try! image.pngData()?.write(to: url)
    return url;
  }
  
  @IBAction func refreshUI(_ sender: UIButton) {
    updateUI();
  }
  
  @IBAction func toggleBorder(_ sender: UIButton) {
    showBorder = !showBorder;
    updateUI();
  }
  
  
  override func didResignActive(with conversation: MSConversation) {
  }
  
  override func didReceive(_ message: MSMessage, conversation: MSConversation) {
  }
  
  override func didStartSending(_ message: MSMessage, conversation: MSConversation) {
  }
  
  override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {
  }
  
  override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
    print(presentationStyle);
  }
  
  override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
  }
  
}

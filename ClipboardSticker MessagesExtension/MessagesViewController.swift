//
//  MessagesViewController.swift
//  ClipboardSticker MessagesExtension
//
//  Created by Nicholas Jitkoff on 7/8/22.
//

import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController, MSStickerBrowserViewDataSource {
  @IBOutlet weak var stickerView: MSStickerView!
  @IBOutlet  var stickerBrowser: MSStickerBrowserView!
  @IBOutlet weak var reloadButton: UIButton!
  @IBOutlet weak var historyButton: UIButton!
  @IBOutlet weak var infoLabel: UITextView!
  @IBOutlet weak var containerView: UIView!
  @IBOutlet weak var toolbarView: UIView!
  
  lazy var files: Array<URL> = {
    return loadSortedFiles()
  }()
  var stickerFile: URL?
  let store = UserDefaults.standard
  var showBorder: Bool
  var stickers: Array<MSSticker> = []
  var content: UIImage?

  required init?(coder: NSCoder) {
    showBorder = (store.object(forKey: "showBorder") != nil) ? store.bool(forKey: "showBorder") : true;
    super.init(coder: coder);
  }
  
  
  func loadSortedFiles() -> Array<URL> {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    guard let directoryURL = URL(string: paths.path) else {return []}
    do {
       return try
       FileManager.default.contentsOfDirectory(at: directoryURL,
              includingPropertiesForKeys:[.contentModificationDateKey],
              options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
           .sorted(by: {
               let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
               let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
               return date0.compare(date1) == .orderedDescending
            })
    } catch {
        print (error)
    }
    return [];
  }
  func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
    return files.count;
  }

  func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
    let url = files[index];
    let sticker =  try! MSSticker(contentsOfFileURL: url, localizedDescription: "Pasted Sticker")
    return sticker;
  }
  
  func fit(size: CGSize, dim: CGFloat) -> CGSize {
    let scale = dim / max(size.width, size.height);
    return CGSize(width: round(size.width * scale), height: round(size.height * scale))
  }
  
  func createStickerFromPasteboard() {
    let pb = UIPasteboard.general;
    print("Pasteboard types:", pb.types, pb.changeCount)
    
    if (!pb.hasImages) {
      infoLabel.isHidden = false
      stickerView.isHidden = true
      return
    }
    
    guard var img = pb.image else { return }
    
    var basename = String(pb.changeCount);
    
    if let url = pb.url {
      basename = NSString(string:url.lastPathComponent).deletingPathExtension
    } else if let data = pb.data(forPasteboardType:"com.apple.mobileslideshow.asset.localidentifier") {
      basename = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "/", with: "_")
    }
    
    let maxSize: CGFloat = 618
    let midSize: CGFloat = 408
    let minSize: CGFloat = 300
    
    var transparent = pb.contains(pasteboardTypes: ["public.png", "public.gif"])
    
    var scale = max(img.size.width, img.size.height) / midSize;
    
    if (scale > 1.0) {
      let size = fit(size:img.size, dim: midSize)
      img = img.resized(to: size)
    }
  
    if (showBorder) {
      transparent = true;
      let distance = 16.0; //max(img.size.width, img.size.height) / 20;
      img = img.stroked(with: .white, thickness: distance, quality: 10)
      img = img.withShadow(blur: distance/2, offset: .init(width: 0, height: distance / 1.25), color: .init(white: 0.2, alpha: 0.333))
      img = img.withShadow(blur: distance, offset: .init(width: 0, height: distance / 2), color: .init(white: 0.2, alpha: 0.15))
    }
    
    var bytes = (transparent ? img.pngData() : img.jpegData(compressionQuality: 0.7))!.count;
    if (bytes > 500000) {
      print("shrinking", bytes)
      let size = fit(size:img.size, dim: minSize)
      img = img.resized(to: size)

//      scale = scale * sqrt(2);
//      img = img.resized(to: CGSize(width:img.size.width / scale, height:img.size.height / scale))
    }
    
    print("image size", img.size.width, img.size.height)
    bytes = (transparent ? img.pngData() : img.jpegData(compressionQuality: 0.7))!.count;

    
    let filename = "\(basename)\(showBorder ? "-border":"")\(transparent ? ".png" : ".jpg")"

    if let oldFile = stickerFile { try? FileManager.default.removeItem(at:oldFile) }
    stickerFile = createFile(image: img, filename: filename);
    print("Writing", stickerFile as Any, img.isTransparent(), bytes)
    let sticker = try? MSSticker(contentsOfFileURL: stickerFile!, localizedDescription: "Pasted Sticker");

    if ((sticker) != nil) {
      stickerView.sticker = sticker
      stickerView.isHidden = false
      toolbarView.isHidden = false
      reloadButton.isHidden = true
      infoLabel.isHidden = true
    }
  }
  override func willBecomeActive(with conversation: MSConversation) {}
  override func didBecomeActive(with conversation: MSConversation) {
    createStickerFromPasteboard()
  }
  
  func createFile(image: UIImage, filename: String) -> URL {
    let fileManager = FileManager.default
    do {
      let documents = try fileManager.url(
        for: .documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
      
    let url = documents.appendingPathComponent(filename)
      
    let type = url.pathExtension
    

      if (type == "jpg") {
        try image.jpegData(compressionQuality: 0.7)?.write(to: url)
      } else {
        try image.pngData()?.write(to: url)
      }
    return url;
      
    } catch { fatalError("Unable to create cache URL: \(error)") }
    
  }
  
  func createFile2(image: UIImage) -> URL {
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
    createStickerFromPasteboard();
  }
  
  @IBAction func setSize(_ sender: UIButton) {
    let size = sender.tag;
    let d = (CGFloat(size) - stickerView.frame.size.width) / 2
    self.stickerView.frame = self.stickerView.frame.insetBy(dx: -d, dy: -d)
  }
  
  @IBAction func toggleBorder(_ sender: UIButton) {
    showBorder = !showBorder;
    store.set(showBorder, forKey: "showBorder")
    store.synchronize();
    createStickerFromPasteboard();
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
    if (presentationStyle == .expanded) {
      stickerBrowser.isHidden = false
      containerView.isHidden = true
      stickerBrowser.dataSource = self
      stickerBrowser.reloadData();
    } else {
      stickerBrowser.isHidden = true
      containerView.isHidden = false
    }
    print(presentationStyle);
  }
  
  override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
  }
  
}


extension UIImage {
  func resized(to size: CGSize) -> UIImage {
    return UIGraphicsImageRenderer(size: size).image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
  public func isTransparent() -> Bool {
    guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
    return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
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

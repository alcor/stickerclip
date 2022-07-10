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
}

class MessagesViewController: MSMessagesAppViewController {
  @IBOutlet weak var stickerView: MSStickerView!
  @IBOutlet weak var infoLabel: UILabel!
  
  func updateUI() {
    
    let pb = UIPasteboard.general;
    print("Pasteboard types:", pb.types)
    
    guard var content = UIPasteboard.general.image else {
      infoLabel.isHidden = false;
      stickerView.isHidden = true;
      return
    }
    
    let maxSize: CGFloat = 512
    
    if (true) {
      content = content.withShadow(blur: 10, offset: CGSize.zero, color: .red)
    }
    
    
    var scale = max(content.size.width, content.size.height) / maxSize;
    
    if (scale > 1.0) {
      content = content.resized(to: CGSize(width:content.size.width / scale, height:content.size.height / scale))
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
    print("Length", image.jpegData(compressionQuality: 0.8)?.count ?? "?")
    let url = cacheURL.appendingPathComponent(fileName)
    try! image.pngData()?.write(to: url)
    return url;
  }
  
  @IBAction func refreshUI(_ sender: UIButton) {
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

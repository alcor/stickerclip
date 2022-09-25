import UIKit
import Messages
import UniformTypeIdentifiers

class MessagesViewController: MSMessagesAppViewController, MSStickerBrowserViewDataSource, UICollectionViewDataSource, UIGestureRecognizerDelegate, NSMetadataQueryDelegate {
  @IBOutlet weak var stickerView: MSStickerView!
  @IBOutlet weak var stickerOutlineView: UIImageView!
  @IBOutlet var stickerBrowser: MSStickerBrowserView!
  @IBOutlet var stickerBrowserContainer: UIView!
  @IBOutlet weak var stickerCollection: UICollectionView!
  @IBOutlet weak var reloadButton: UIButton!
  @IBOutlet weak var historyButton: UIButton!
  @IBOutlet weak var deleteButton: UIButton!
  @IBOutlet weak var selectButton: UIButton!
  @IBOutlet weak var instructionsLabel: UITextView!
  @IBOutlet weak var dragHintLabel: UIButton!
  @IBOutlet weak var pasteHintLabel: UIButton!
  @IBOutlet weak var containerView: UIView!
  @IBOutlet weak var toolbarView: UIView!
  @IBOutlet weak var instructionsView: UIView!
  @IBOutlet weak var editorView: UIView!
  @IBOutlet weak var pasteControl: UIControl!
  
  var sizes = [618, 516, 408, 300, 192]
  var size = 408
  var forcePaste = false
  
  lazy var files: Array<URL> = {
    let files = loadSortedFiles()
    return files
  }()
  var stickerFile: URL?
  let store = UserDefaults.standard
  var showBorder: Bool
  var stickers: Array<MSSticker> = []
  var content: UIImage?
  var selectedStickers: Array<String> = []
  required init?(coder: NSCoder) {
    showBorder = (store.object(forKey: "showBorder") != nil) ? store.bool(forKey: "showBorder") : true;
    super.init(coder: coder);
    
    migrateOldFiles()
    forceCloudSync()
  }
  override func awakeFromNib() {
    stickerCollection.allowsSelection = false;
  }
  

  func loadSortedFiles() -> Array<URL> {
    let directoryURL = getDocumentsDirectory()
   
    do {
      let files = try
      FileManager.default.contentsOfDirectory(at: directoryURL,
                                              includingPropertiesForKeys:[.contentModificationDateKey],
                                              options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
      .sorted(by: {
        let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
        let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
        return date0.compare(date1) == .orderedDescending
      })
      
      print("Loaded \(files.count) stickers") //, files.map({ url in url.lastPathComponent }).joined(separator:"\n"))
      return files;
    } catch {
      print ("ERROR:", error)
      showInstructions(true)
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
  
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return files.count
  }
  
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Sticker", for: indexPath)
    let stickerView = cell.contentView as? MSStickerView
    
    let url = files[indexPath.item % files.count];
    let sticker =  try! MSSticker(contentsOfFileURL: url, localizedDescription: "Pasted Sticker")
    
    if cell.isSelected == true {
      cell.backgroundColor = .green
    }
    stickerView?.startAnimating()
    stickerView?.sticker = sticker
    
    let selected = selectedStickers.contains(url.absoluteString);

    let stickerViewTapGesture = UITapGestureRecognizer(target: self, action: #selector(stickerCellSelection))
    stickerViewTapGesture.name = url.absoluteString
    stickerViewTapGesture.delegate = self
    stickerView?.addGestureRecognizer(stickerViewTapGesture)
    
    let stickerViewHoldGesture = UILongPressGestureRecognizer(target: self, action: #selector(stickerCellPeel))
    stickerViewHoldGesture.name = url.absoluteString
    stickerViewHoldGesture.delegate = self
    stickerViewHoldGesture.minimumPressDuration = 0.2;
    stickerView?.addGestureRecognizer(stickerViewHoldGesture)
    
    if (selected) {
      cell.backgroundColor = .systemRed
      cell.layer.cornerRadius = 10
    } else {
      cell.backgroundColor = .clear
    }
    
    
    cell.isSelected = selected;
    return cell
  }
  
  @objc func stickerCellSelection(recognizer: UITapGestureRecognizer) {

    if (!stickerCollection.allowsSelection) {
      touchSticker(recognizer.name)
      return
    };
    
    let path = stickerCollection.indexPath(for: recognizer.view!.superview as! UICollectionViewCell)
    
    if let name = recognizer.name {
      print("Selected Sticker:  \(name)")
      if let index = selectedStickers.firstIndex(of: name) {
        selectedStickers.remove(at: index)
      } else {
        selectedStickers.append(name)
      }
      stickerCollection.selectItem(at: path, animated: true, scrollPosition: .top)
      stickerCollection.reloadData()
      
    }
  }
  
  @objc func stickerCellPeel(recognizer: UILongPressGestureRecognizer) {
    if ( recognizer.state == .began) {
      touchSticker(recognizer.name)
    }
  }
  
  func touchSticker(_ name: String?) {
    guard let urlString = name else { return }
    guard var url = URL(string:urlString) else { return }
    print("Touching Sticker:  \(url.lastPathComponent)")
    var resourceValues = URLResourceValues()
    resourceValues.contentModificationDate = Date()
    try? url.setResourceValues(resourceValues)
  }
  
  func collectionView(_ collectionView: UICollectionView,
                      layout collectionViewLayout: UICollectionViewLayout,
                      sizeForItemAt indexPath: IndexPath) -> CGSize {
    // your code here
    return CGSize(width: 10, height: 10)
  }
  
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                         shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    
    if (gestureRecognizer is UITapGestureRecognizer) {
      return !stickerCollection.allowsSelection
    } else {
      return true;
    }
  }
  
  override func canPaste(_ itemProviders: [NSItemProvider]) -> Bool {
    if (itemProviders.count == 0) {
      showInstructions(itemProviders.count == 0);
    }
    return true;
  }
  
  override func paste(itemProviders: [NSItemProvider]) {
    Task {
      await createFrom(itemProviders: itemProviders)
    }
  }
  
  func createFrom(itemProviders: [NSItemProvider]) async {
    if (itemProviders.count == 0) {
      showInstructions(true)
      return
    }
    do {
      let itemProvider = itemProviders.first!
      let types = itemProvider.registeredTypeIdentifiers
      let image = await itemProvider.loadObject(ofClass: UIImage.self) as? UIImage
      let url = await itemProvider.loadObject(ofClass: NSURL.self) as? URL
      let string = await itemProvider.loadObject(ofClass: NSString.self) as? String
      var type = "public.data";
      for t in types {
        if (UTTypeReference(t)?.conforms(to: .image) ?? false) {
          type = t;
          break;
        }
      }
      
      var data: Data?
      if (image != nil) {
        if let dataPath = try await itemProvider.loadItem(forTypeIdentifier: type) as? URL {
          if dataPath.startAccessingSecurityScopedResource() {
            data = try Data(contentsOf: dataPath)
          }
        }
      }
      
      var name = itemProvider.suggestedName
      
      if (url != nil) {
        name = NSString(string:url!.lastPathComponent).deletingPathExtension
      }
      
      
      createSticker(image: image, string: string, url: url, basename: name, type: type, data:data)
    } catch {
      print("Unable to create sticker: \(error)")
      
    }
  }
  
  func createStickerFromPasteboard() {
    let pb = UIPasteboard.general;
    Task {
      await createFrom(itemProviders:pb.itemProviders)
    }
    return;
  }
  
  func showInstructions(_ state: Bool = true) {
    if (state) {
      self.view = instructionsView
    } else {
      self.view = editorView
    }
  }
  
  func createSticker(image: UIImage?, string: String?, url: URL?, basename: String?, type: String, data: Data?) {
    
    var type = type;
    var basename = basename
    
    var transparent = type == "public.png";
    showInstructions(image == nil && string == nil && url == nil)
    
    //  let maxSize: CGFloat = 618
    let manSize: CGFloat = 534
    //    let midSize: CGFloat = 408
    let minSize: CGFloat = 300
    
    var textImg: UIImage?
    if (image == nil) {
      if let string = string {
        print ("Creating image from string", string)
        transparent = true
        type = UTType.png.identifier
        let style = NSMutableParagraphStyle()
        style.alignment = NSTextAlignment.center
        if (string.count <= 3) {
          let fontSize = 320.0;
          let font = UIFont.boldSystemFont(ofSize: fontSize)
          textImg = string.image( withAttributes: [.foregroundColor: UIColor.darkText, .font: font, .paragraphStyle:style], size:CGSize(width:fontSize, height:fontSize), offsetY: (fontSize - font.lineHeight)/2)
        } else {
          let font = UIFont.boldSystemFont(ofSize: 160.0)
          textImg = string.image( withAttributes: [.foregroundColor: UIColor.darkText, .font: font, .paragraphStyle:style])
          
        }
        basename = String(string.prefix(100)).replacingOccurrences(of: "/", with: "_")
      }
    } else {
      print("Creating image with", image as Any)
      
    }
    
    guard var img = textImg ?? image else { return }
    
    let initialSize = img.size;
    
    let scale = max(img.size.width, img.size.height) / manSize;
    if (scale > 1.0) {
      let size = fit(size:img.size, dim: manSize)
      img = img.resized(to: size)
    }
    print("Cropped Size:", img.size, img.pngData()!.count);
    
    if (showBorder) {
      transparent = true;
      let distance = max(img.size.width, img.size.height) / 20;
      img = img.stroked(with: .white, thickness: distance, quality: 8)
      img = img.withShadow(blur: distance/2, offset: .init(width: 0, height: distance / 4), color: .init(white: 0.2, alpha: 0.333))
    }
    
    let maxSize = 500 * 1024;
    var bytes = (transparent ? img.pngData() : img.jpegData(compressionQuality: 0.7))!.count;
    if (bytes >= maxSize) {
      let size = fit(size:img.size, dim: minSize)
      img = img.resized(to: size)
    }
    
    bytes = (transparent ? img.pngData() : img.jpegData(compressionQuality: 0.7))!.count;
    print("Final Size:  ", img.size, bytes);
    
    var filesize = bytes
    var originalFileData: Data? = nil
    
    var ext = UTTypeReference(type)?.preferredFilenameExtension ?? "png";
    
    // If the size is unchanged, and original file was smaller, use its data.
    if (initialSize == img.size && data != nil && data!.count < maxSize) {
      originalFileData = data
      filesize = data!.count
    } else {
      ext = transparent ? "png" : "jpg"
    }
    
    if (basename == nil || basename == "") { basename = "sticker" }
    let filename = "\(basename!)\(showBorder ? "-border":"")-\(String(filesize)).\(ext)"
    
    if let oldFile = stickerFile { try? FileManager.default.removeItem(at:oldFile) }
    

    let directory = getDocumentsDirectory()
    let url = directory.appendingPathComponent(filename)
    
    
    
    stickerFile = createFile(image: img, originalFileData:originalFileData, url:url);
    let sticker = try? MSSticker(contentsOfFileURL: stickerFile!, localizedDescription: "Pasted Sticker");
    
    if ((sticker) != nil) {
      stickerView.sticker = sticker
      stickerView.isHidden = false
      toolbarView.isHidden = false
      pasteHintLabel.isHidden = true
      dragHintLabel.isHidden = false
      pasteControl?.isHidden = true
    }
  }
  
  override func willBecomeActive(with conversation: MSConversation) {}
  override func didBecomeActive(with conversation: MSConversation) {
    if #available(iOS 16, *) {
      let config = UIPasteControl.Configuration()
      config.baseBackgroundColor = .systemBackground//.white//.init(red: 250/256, green: 194/256, blue: 43/256, alpha: 1.0);
      config.baseForegroundColor = .label//.black
      config.displayMode = .iconOnly
      config.cornerStyle = .capsule
      let control = UIPasteControl(configuration: config)
      control.target = self
      control.frame = stickerView.frame.inset(by: .init(top: 10, left: 10, bottom: 10, right: 10));
      control.autoresizingMask = stickerView.autoresizingMask;
      
      stickerView.superview?.addSubview(control);
      pasteControl = control
      showInstructions(!UIPasteboard.general.hasImages && !UIPasteboard.general.hasStrings)
    } else {
      if (UIPasteboard.general.hasImages) {
        createStickerFromPasteboard()
      } else {
        showInstructions(true);
      }
    }
  }
  
  func createFile(image: UIImage, originalFileData: Data?, url: URL) -> URL {
    print("Writing sticker:", image, originalFileData ?? "nodata",  url)
    do {
      
      let type = url.pathExtension
      if (originalFileData != nil) {
        try originalFileData!.write(to: url)
      } else if (type == "jpg" || type == "jpeg") {
        try image.jpegData(compressionQuality: 0.7)?.write(to: url)
      } else {
        try image.pngData()?.write(to: url)
      }
      return url;
      
    } catch { fatalError("Unable to create cache URL: \(error)") }
    
  }
  
  func fit(size: CGSize, dim: CGFloat) -> CGSize {
    let scale = dim / max(size.width, size.height);
    return CGSize(width: round(size.width * scale), height: round(size.height * scale))
  }
  
  @IBAction func refreshUI(_ sender: UIButton) {
    forcePaste = true
    createStickerFromPasteboard();
  }
  
  @IBAction func selectStickers(_ sender: UIButton) {
    stickerCollection.allowsSelection = !stickerCollection.allowsSelection;
    stickerCollection.allowsMultipleSelection = stickerCollection.allowsSelection
    stickerCollection.reloadData();
    selectButton.isSelected = stickerCollection.allowsSelection
    deleteButton.isHidden = !stickerCollection.allowsSelection
  }
  
  @IBAction func deleteStickers(_ sender: UIButton) {
    print("Deleting \(selectedStickers)")
    selectedStickers.forEach { fileURL in
      if let url = URL(string: fileURL) {
        try? FileManager.default.removeItem(at: url)
        
      }
    }
    selectStickers(deleteButton)
    selectedStickers = []
    files = loadSortedFiles()
    stickerCollection.reloadData()
  }
  
  func forceCloudSync() {
    print("Syncing Cloud")
    
    let metadataQuery = NSMetadataQuery()
    metadataQuery.notificationBatchingInterval = 1
    metadataQuery.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
    metadataQuery.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
    
    NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidUpdate, object: nil, queue: .main) { notif in
      metadataQuery.disableUpdates()
//      print("Notif", notif, notif.userInfo);
       let changedMetadataItems = notif.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem]
       let removedMetadataItems = notif.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem]
       let addedMetadataItems = notif.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem]
      
//      print("Updated", addedMetadataItems, removedMetadataItems, changedMetadataItems)

      for result in addedMetadataItems! {
        if let item = result as? NSMetadataItem {
          print("Added", result)
          guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
          self.files = self.loadSortedFiles()
          self.stickerCollection.reloadData();
        }
      }
      for result in removedMetadataItems! {
        if let item = result as? NSMetadataItem {
          print("Added", result)
          guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
          
          self.files = self.loadSortedFiles()
          self.stickerCollection.reloadData();
        }
      }
      metadataQuery.enableUpdates()

    }
    NotificationCenter.default.addObserver(forName: UIDocument.stateChangedNotification, object: nil, queue: .main) { notif in
      print("Notif", notif)
    }
    NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil, queue: .main) { notif in
      print("Notif:", notif);
      
      for result in metadataQuery.results {
        if let item = result as? NSMetadataItem {
          guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { continue }
          do {
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            print("Downloading", url.lastPathComponent)
          } catch {
            print("Download error", error)
          }
          
        }
       
      }
    }
    metadataQuery.start()
  }
  
  
  func migrateOldFiles() {
    guard let cloudDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") else { return }
    
    let localDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    print("Checking for local files to migrate:\n", cloudDirectory.path,"\n", localDirectory.path);

    do {
      let files = try FileManager.default.contentsOfDirectory(at: localDirectory, includingPropertiesForKeys: nil);
      
      if (files.count == 0) {
        return
      }
      print("Files to Migrate:", files);
      
      try files.forEach { source in
        let destination = cloudDirectory.appendingPathComponent(source.lastPathComponent, isDirectory: false)
        print("Moving", source.lastPathComponent, "to", destination)

        try? FileManager.default.moveItem(at: source, to: destination)
        try? FileManager.default.removeItem(at: source)

      }
    } catch {
      print ("ERROR:", error)
    }
    

    
  }
  
  func getDocumentsDirectory() -> URL { // returns your iCloud or local documents folder
    let documentsDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return documentsDirectory
  }
  
  @IBAction func showRecents(_ sender: UIButton) {
    self.requestPresentationStyle(.expanded)
  }
  
  @IBAction func setSize(_ sender: UIButton) {
    let dir = sender.tag * -1
    var i = sizes.firstIndex(of: size) ?? 2
    i += dir
    i = min(sizes.count - 1, max(0, i))
    size = sizes[i]
    print("Adjusting size to \(size)")
    let ptSize = size / 3
    let d = (CGFloat(ptSize) - stickerView.frame.size.width) / 2
    self.stickerView.frame = self.stickerView.frame.insetBy(dx: -d, dy: -d)
  }
  
  @IBAction func toggleBorder(_ sender: UIButton) {
    showBorder = !showBorder;
    store.set(showBorder, forKey: "showBorder")
    store.synchronize();
    createStickerFromPasteboard();
  }
  
  //  override func didResignActive(with conversation: MSConversation) {}
  
  //  override func didReceive(_ message: MSMessage, conversation: MSConversation) {}
  
  //  override func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
  
  //  override func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
  
  override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
    if (presentationStyle == .expanded) {
      self.view = stickerBrowserContainer
      stickerBrowserContainer.isHidden = false
      stickerCollection.dataSource = self
      stickerCollection.reloadData();
    } else {
      self.view = editorView;
      stickerBrowserContainer.isHidden = true
    }
  }
  
  //  override func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
  
}


extension UIImage {
  func resized(to size: CGSize) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = self.scale
    return UIGraphicsImageRenderer(size: size, format:format).image { _ in
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
      false, self.scale
    )
    
    let context = UIGraphicsGetCurrentContext()!
    
    context.setShadow( offset: offset, blur: blur, color: color.cgColor )
    
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

extension String {
  
  /// Generates a `UIImage` instance from this string using a specified
  /// attributes and size.
  ///
  /// - Parameters:
  ///     - attributes: to draw this string with. Default is `nil`.
  ///     - size: of the image to return.
  /// - Returns: a `UIImage` instance from this string using a specified
  /// attributes and size, or `nil` if the operation fails.
  func image(withAttributes attributes: [NSAttributedString.Key: Any]? = nil, size: CGSize? = nil, offsetY: CGFloat = 0.0) -> UIImage? {
    
    var size = size ?? (self as NSString).size(withAttributes: attributes)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: size, format:format).image { ctx in
      size.height *= 2;
      (self as NSString).draw(in: CGRect(origin: CGPoint(x: 0, y: offsetY), size: size), withAttributes: attributes)
      
    }
  }
  
}



extension NSItemProvider {
  
  func loadObject(ofClass aClass: NSItemProviderReading.Type) async -> NSItemProviderReading? {
    guard self.canLoadObject(ofClass: aClass) else { return nil }
    
    return await withCheckedContinuation({ continuation in
      self.loadObject(ofClass: aClass, completionHandler: { (data, error) in
        //        print("Returning \(data), error=\(error)")
        continuation.resume(returning: data)
      })
    })
    
  }
}

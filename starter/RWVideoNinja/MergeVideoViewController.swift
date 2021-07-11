/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import MediaPlayer
import MobileCoreServices
import UIKit
import Photos


class MergeVideoViewController: UIViewController {
  var firstAsset: AVAsset?
  var secondAsset: AVAsset?
  var audioAsset: AVAsset?
  var loadingAssetOne = false
  
  @IBOutlet var activityMonitor: UIActivityIndicatorView!
  
  func savedPhotosAvailable() -> Bool {
    guard !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum)
    else { return true }
    
    let alert = UIAlertController(
      title: "Not Available",
      message: "No Saved Album found",
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(
                      title: "OK",
                      style: UIAlertAction.Style.cancel,
                      handler: nil))
    present(alert, animated: true, completion: nil)
    return false
  }
  
  @IBAction func loadAssetOne(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = true
      VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
  }
  
  @IBAction func loadAssetTwo(_ sender: AnyObject) {
    if savedPhotosAvailable() {
      loadingAssetOne = false
      VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
//      VideoHelper.startImageBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }
  }
  
  @IBAction func loadAudio(_ sender: AnyObject) {
    let mediaPickerController = MPMediaPickerController(mediaTypes: .any)
    mediaPickerController.delegate = self
    mediaPickerController.prompt = "Select Audio"
    present(mediaPickerController, animated: true, completion: nil)
  }
  
  @IBAction func merge(_ sender: AnyObject) {
    guard
      let firstAsset = firstAsset,
      let secondAsset = secondAsset
    else { return }
    
    activityMonitor.startAnimating()
    
    // 1
    let mixComposition = AVMutableComposition()
    
    // 2
    guard
      let firstTrack = mixComposition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
    else { return }
    
    // 3
    do {
      try firstTrack.insertTimeRange(
        CMTimeRangeMake(start: .zero, duration: firstAsset.duration),
        of: firstAsset.tracks(withMediaType: .video)[0],
        at: .zero)
    } catch {
      print("Failed to load first track")
      return
    }
    
    // 4
    guard
      let secondTrack = mixComposition.addMutableTrack(
        withMediaType: .video,
        preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
    else { return }
    
    do {
      try secondTrack.insertTimeRange(
        CMTimeRangeMake(start: .zero, duration: secondAsset.duration),
        of: secondAsset.tracks(withMediaType: .video)[0],
        at: firstAsset.duration)
    } catch {
      print("Failed to load second track")
      return
    }
    
    // 5
    // 6
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(
      start: .zero,
      duration: CMTimeAdd(firstAsset.duration, secondAsset.duration))
    
    // 7
    let firstInstruction = VideoHelper.videoCompositionInstruction(
      firstTrack,
      asset: firstAsset)

    firstInstruction.setOpacity(0.0, at: firstAsset.duration)
    let secondInstruction = VideoHelper.videoCompositionInstruction(
       secondTrack,
       asset: secondAsset)

    
    // 8
    mainInstruction.layerInstructions = [firstInstruction, secondInstruction]
    let mainComposition = AVMutableVideoComposition()
    mainComposition.instructions = [mainInstruction]
    mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
    mainComposition.renderSize = CGSize(
      width: UIScreen.main.bounds.width,
      height: UIScreen.main.bounds.height)
    
    // 9
    // 10
    if let loadedAudioAsset = audioAsset {
      let audioTrack = mixComposition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: 0)
      do {
        try audioTrack?.insertTimeRange(
          CMTimeRangeMake(
            start: .zero,
            duration: CMTimeAdd(
              firstAsset.duration,
              secondAsset.duration)),
          of: loadedAudioAsset.tracks(withMediaType: .audio)[0],
          at: .zero)
      } catch {
        print("Failed to load Audio track")
      }
    }
    
    // 11
    guard
      let documentDirectory = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask).first
    else { return }
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .long
    dateFormatter.timeStyle = .short
    let date = dateFormatter.string(from: Date())
    let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
    
    // 12
    guard let exporter = AVAssetExportSession(
            asset: mixComposition,
            presetName: AVAssetExportPresetHighestQuality)
    else { return }
    exporter.outputURL = url
    exporter.outputFileType = AVFileType.mov
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = mainComposition
    
    // 13
    exporter.exportAsynchronously {
      DispatchQueue.main.async {
        self.exportDidFinish(exporter)
      }
    }
  }
  
  func exportDidFinish(_ session: AVAssetExportSession) {
    // 1
    activityMonitor.stopAnimating()
    firstAsset = nil
    secondAsset = nil
    audioAsset = nil
    
    // 2
    guard
      session.status == AVAssetExportSession.Status.completed,
      let outputURL = session.outputURL
    else { return }
    
    // 3
    let saveVideoToPhotos = {
      // 4
      let changes: () -> Void = {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
      }
      PHPhotoLibrary.shared().performChanges(changes) { saved, error in
        DispatchQueue.main.async {
          let success = saved && (error == nil)
          let title = success ? "Success" : "Error"
          let message = success ? "Video saved" : "Failed to save video"
          
          let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert)
          alert.addAction(UIAlertAction(
                            title: "OK",
                            style: UIAlertAction.Style.cancel,
                            handler: nil))
          self.present(alert, animated: true, completion: nil)
        }
      }
    }
    
    // 5
    if PHPhotoLibrary.authorizationStatus() != .authorized {
      PHPhotoLibrary.requestAuthorization { status in
        if status == .authorized {
          saveVideoToPhotos()
        }
      }
    } else {
      saveVideoToPhotos()
    }
  }
  
}

// MARK: - UIImagePickerControllerDelegate
extension MergeVideoViewController: UIImagePickerControllerDelegate {
  func imagePickerController(
    _ picker: UIImagePickerController,
    didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
  ) {
    dismiss(animated: true, completion: nil)
    
    guard let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String,
          mediaType == "public.movie",
          let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL
    else { return }
    
//    guard let photoTypePicker = info[UIImagePickerController.InfoKey.mediaType] as? String,
//          photoTypePicker == (kUTTypeImage as String),
//          let imageUrl = info[UIImagePickerController.InfoKey.mediaURL] as? URL
//    else { return }
//
    let avAsset = AVAsset(url: url)
//    let imageAsset = AVAsset(url: imageUrl)
    
    var message = ""
    if loadingAssetOne {
      message = "Video one loaded"
      firstAsset = avAsset
      print(firstAsset as Any)
    } else {
      message = "Video two loaded"
      secondAsset = avAsset
      print(secondAsset as Any)
    }
    let alert = UIAlertController(
      title: "Asset Loaded",
      message: message,
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(
                      title: "OK",
                      style: UIAlertAction.Style.cancel,
                      handler: nil))
    present(alert, animated: true, completion: nil)
  }
}

// MARK: - UINavigationControllerDelegate
extension MergeVideoViewController: UINavigationControllerDelegate {
}

// MARK: - MPMediaPickerControllerDelegate
extension MergeVideoViewController: MPMediaPickerControllerDelegate {
  func mediaPicker(
    _ mediaPicker: MPMediaPickerController,
    didPickMediaItems mediaItemCollection: MPMediaItemCollection
  ) {
    // 1
    dismiss(animated: true) {
      // 2
      let selectedSongs = mediaItemCollection.items
      guard let song = selectedSongs.first else { return }
      
      // 3
      let title: String
      let message: String
      if let url = song.value(forProperty: MPMediaItemPropertyAssetURL) as? URL {
        self.audioAsset = AVAsset(url: url)
        title = "Asset Loaded"
        message = "Audio Loaded"
      } else {
        self.audioAsset = nil
        title = "Asset Not Available"
        message = "Audio Not Loaded"
      }
      
      // 4
      let alert = UIAlertController(
        title: title,
        message: message,
        preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
      self.present(alert, animated: true, completion: nil)
    }
  }
  
  func mediaPickerDidCancel(_ mediaPicker: MPMediaPickerController) {
    // 5
    dismiss(animated: true, completion: nil)
  }
  
}

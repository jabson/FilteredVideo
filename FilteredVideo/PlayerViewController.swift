//
//  PlayerViewController.swift
//  FilteredVideo
//
//  Created by jaba odishelashvili on 4/5/18.
//  Copyright © 2018 Jabson. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

class PlayerViewController: UIViewController {
    //MARK: IBOutlet
    @IBOutlet var importButtonItem: UIBarButtonItem!
    @IBOutlet var exportButtonItem: UIBarButtonItem!
    
    //MARK: variables
    var videoComposition: AVVideoComposition?
    var videoAsset: AVAsset?
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var outputVideoPath: String {
        get{
            let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
            return "\(cachesDirectory[0])/video.mp4"
        }
    }
    
    //MARK: Object Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }
    
    //MARK: User Interface Methods
    @IBAction func importVideo(_ sender: Any) {
        let imagePickerController = UIImagePickerController()
        imagePickerController.sourceType = .photoLibrary
        imagePickerController.delegate = self
        imagePickerController.mediaTypes = ["public.movie"]
        present(imagePickerController, animated: true, completion: nil)
    }
    
    @IBAction func exportVideo(_ sender: Any) {
        guard let videoAsset = videoAsset else { return }
        guard let videoComposition = videoComposition else { return }
        
        let fileManager = FileManager()
        let videoPath = outputVideoPath
        
        if fileManager.fileExists(atPath: videoPath) {
            try? fileManager.removeItem(atPath: videoPath)
        }
        
        guard let exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPresetHighestQuality) else { return }
        exportSession.outputURL = URL(fileURLWithPath: outputVideoPath)
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.videoComposition = videoComposition;
        
        self.exportButtonItem.isEnabled = false
        exportSession.exportAsynchronously { [weak self] in
            switch exportSession.status {
            case .completed:
                self?.saveVideoToLibrary(from: videoPath)
                DispatchQueue.main.async {
                    self?.exportButtonItem.isEnabled = true
                }
            case .cancelled, .failed:
                DispatchQueue.main.async {
                    self?.exportButtonItem.isEnabled = true
                }
            default: break
            }
        }
    }
    
    //MARK: private methods
    private func createVideoComposition() {
        guard let videoAsset = videoAsset else { return }
        guard let filter = CIFilter(name: "CIPhotoEffectNoir") else { return }
        
        videoComposition = AVVideoComposition(asset: videoAsset) { request in
            let sourceImage = request.sourceImage
            filter.setValue(sourceImage, forKey: kCIInputImageKey)
            let filteredImage = filter.outputImage
            
            if filteredImage != nil {
                request.finish(with: filteredImage!, context: nil)
            } else {
                request.finish(with: sourceImage, context: nil)
            }
        }
    }
    
    private func createPlayer() {
        guard let videoAsset = videoAsset else { return }
        guard let videoComposition = videoComposition else { return }
        
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        
        let playerItem = AVPlayerItem(asset: videoAsset)
        playerItem.videoComposition = videoComposition
        self.player = AVPlayer(playerItem: playerItem)
        
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer!)
        self.player?.play()
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerFinishedPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
    
    @objc private func playerFinishedPlaying(notification: Notification) {
        self.player?.seek(to: kCMTimeZero)
        self.player?.play()
    }
    
    private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void ) {
        let authorizationStatus = PHPhotoLibrary.authorizationStatus()
        
        switch authorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                completion((status == .authorized))
            })
        case .authorized:
            completion(true)
        case .denied, .restricted:
            completion(false)
        }
    }
    
    private func saveVideoToLibrary(from path: String) {
        self.requestPhotoLibraryAccess(completion: { (granted) in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
            }) { saved, error in
                if saved == true {
                    DispatchQueue.main.async { [weak self] in
                        self?.showSaveLibraryAlert()
                    }
                }
            }
        })
    }
    
    private func showSaveLibraryAlert() {
        let alert = UIAlertController(title: "Video Saved", message: "Video saved to your library", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Got it", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

extension PlayerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @objc public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        guard let videoURL = info[UIImagePickerControllerMediaURL] as? URL else { return }
        self.videoAsset = AVAsset(url: videoURL)
        exportButtonItem.isEnabled = true
        createVideoComposition()
        createPlayer()
        picker.dismiss(animated: true, completion: nil)
    }
    
    @objc public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

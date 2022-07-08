//  Runner
//
//  Created by Kapil on 14/12/21.


import Foundation
import AVKit
import AVFoundation
import MobileCoreServices
extension CGSize {
    
    static func aspectFit(videoSize: CGSize, boundingSize: CGSize) -> CGSize {
        
        var size = boundingSize
        let mW = boundingSize.width / videoSize.width;
        let mH = boundingSize.height / videoSize.height;
        
        if( mH < mW ) {
            size.width = boundingSize.height / videoSize.height * videoSize.width;
        }
        else if( mW < mH ) {
            size.height = boundingSize.width / videoSize.width * videoSize.height;
        }
        
        return size;
    }
    
    static func aspectFill(videoSize: CGSize, boundingSize: CGSize) -> CGSize {
        
        var size = boundingSize
        let mW = boundingSize.width / videoSize.width;
        let mH = boundingSize.height / videoSize.height;
        
        if( mH > mW ) {
            size.width = boundingSize.height / videoSize.height * videoSize.width;
        }
        else if ( mW > mH ) {
            size.height = boundingSize.width / videoSize.width * videoSize.height;
        }
        
        return size;
    }
}
class VideoScaling
{
    var size: CGSize = CGSize(width: 720, height: 1280)
    func scaleAndPositionInAspectFitMode(forTrack track:AVAssetTrack, inArea area: CGSize) -> (scale: CGSize, position: CGPoint) {
        let assetSize = self.assetSize(forTrack: track)
        let aspectFitSize  = CGSize.aspectFit(videoSize: assetSize, boundingSize: area)
        let aspectFitScale = CGSize(width: aspectFitSize.width/assetSize.width, height: aspectFitSize.height/assetSize.height)
        let position = CGPoint(x: (area.width - aspectFitSize.width)/2.0, y: (area.height - aspectFitSize.height)/2.0)
        return (scale: aspectFitScale, position: position)
    }
    func assetSize(forTrack videoTrack:AVAssetTrack) -> CGSize {
        let size = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        return CGSize(width: fabs(size.width), height: fabs(size.height))
    }
    func RadiansToDegree(radians: CGFloat) -> CGFloat {
        return (radians * 180.0)/(CGFloat)(Double.pi)
    }
    func aspectFill(videoSize: CGSize, boundingSize: CGSize) -> CGSize {
        
        var size = boundingSize
        let mW = boundingSize.width / videoSize.width;
        let mH = boundingSize.height / videoSize.height;
        
        if( mH > mW ) {
            size.width = boundingSize.height / videoSize.height * videoSize.width;
        }
        else if ( mW > mH ) {
            size.height = boundingSize.width / videoSize.width * videoSize.height;
        }
        
        return size;
    }
    func getVideoOrientation(forTrack videoTrack:AVAssetTrack) -> UIImage.Orientation {
        let txf: CGAffineTransform = videoTrack.preferredTransform
        let videoAngleInDegree: CGFloat = RadiansToDegree(radians: atan2(txf.b, txf.a))
        var orientation: UIImage.Orientation = .up
        switch (Int)(videoAngleInDegree) {
        case 0:
            orientation = .right
            break
        case 90:
            orientation = .up
            break
        case 180:
            orientation = .left
            break
        case -90:
            orientation = .down
            break
        default:
            orientation = .up
            break
        }
        return orientation
    }
    
    func scaleVideo(videos: [AVAsset],startTimeInSeconds:Double,endTimeInSeconds:Double,writingPath:URL,complete:@escaping FlutterResult) {
        
        let startTime = CMTime(seconds: Double(startTimeInSeconds), preferredTimescale: 1000)
        let endTime = CMTime(seconds: Double(endTimeInSeconds), preferredTimescale: 1000)
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        // Create AVMutableComposition Object.This object will hold our multiple AVMutableCompositionTrack.
        let mixComposition = AVMutableComposition()
        
        var instructionLayers : Array<AVMutableVideoCompositionLayerInstruction> = []
        
        
        
        /// Add other videos at center of the blur video
        var startAt = CMTime.zero
        for asset in videos {
            
            /// Time Range of asset
            let timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
            
            // Here we are creating the AVMutableCompositionTrack. See how we are adding a new track to our AVMutableComposition.
            let track = mixComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            // Now we set the length of the track equal to the length of the asset and add the asset to out newly created track at kCMTimeZero for first track and lastAssetTime for current track so video plays from the start of the track to end.
            if let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {
                
                /// Hide time for this video's layer
                let opacityStartTime: CMTime = CMTimeMakeWithSeconds(0, preferredTimescale: asset.duration.timescale)
                let opacityEndTime: CMTime = CMTimeAdd(startAt, asset.duration)
                let hideAfter: CMTime = CMTimeAdd(opacityStartTime, opacityEndTime)
                
                /// Adding video track
                try? track?.insertTimeRange(timeRange, of: videoTrack, at: startAt)
                
                /// Layer instrcution
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track!)
                layerInstruction.setOpacity(0.0, at: hideAfter)
                
                /// Add logic for aspectFit in given area
                let properties = scaleAndPositionInAspectFitMode(forTrack: videoTrack, inArea: size)
                
                /// Checking for orientation
                let videoOrientation: UIImage.Orientation = self.getVideoOrientation(forTrack: videoTrack)
                let assetSize = self.assetSize(forTrack: videoTrack)
                
                if (videoOrientation == .down) {
                    /// Rotate
                    let defaultTransfrom = asset.preferredTransform
                    let rotateTransform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi/2.0))
                    
                    // Scale
                    let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)
                    
                    // Translate
                    var ytranslation: CGFloat = assetSize.height
                    var xtranslation: CGFloat = 0
                    if properties.position.y == 0 {
                        xtranslation = -(assetSize.width - ((size.width/size.height) * assetSize.height))/2.0
                    }
                    else {
                        ytranslation = assetSize.height - (assetSize.height - ((size.height/size.width) * assetSize.width))/2.0
                    }
                    let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)
                    
                    // Final transformation - Concatination
                    let finalTransform = defaultTransfrom.concatenating(rotateTransform).concatenating(translationTransform).concatenating(scaleTransform)
                    layerInstruction.setTransform(finalTransform, at: CMTime.zero)
                }
                else if (videoOrientation == .left) {
                    
                    /// Rotate
                    let defaultTransfrom = asset.preferredTransform
                    let rotateTransform = CGAffineTransform(rotationAngle: -CGFloat(Double.pi))
                    
                    // Scale
                    let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)
                    
                    // Translate
                    var ytranslation: CGFloat = assetSize.height
                    var xtranslation: CGFloat = assetSize.width
                    if properties.position.y == 0 {
                        xtranslation = assetSize.width - (assetSize.width - ((size.width/size.height) * assetSize.height))/2.0
                    }
                    else {
                        ytranslation = assetSize.height - (assetSize.height - ((size.height/size.width) * assetSize.width))/2.0
                    }
                    let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)
                    
                    // Final transformation - Concatination
                    let finalTransform = defaultTransfrom.concatenating(rotateTransform).concatenating(translationTransform).concatenating(scaleTransform)
                    layerInstruction.setTransform(finalTransform, at: CMTime.zero)
                }
                else if (videoOrientation == .right) {
                    /// No need to rotate
                    // Scale
                    let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)
                    
                    // Translate
                    let translationTransform = CGAffineTransform(translationX: properties.position.x, y: properties.position.y)
                    
                    let finalTransform  = scaleTransform.concatenating(translationTransform)
                    layerInstruction.setTransform(finalTransform, at: CMTime.zero)
                }
                else {
                    /// Rotate
                    let defaultTransfrom = asset.preferredTransform
                    let rotateTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi/2.0))
                    
                    // Scale
                    let scaleTransform = CGAffineTransform(scaleX: properties.scale.width, y: properties.scale.height)
                    
                    // Translate
                    var ytranslation: CGFloat = 0
                    var xtranslation: CGFloat = assetSize.width
                    if properties.position.y == 0 {
                        xtranslation = assetSize.width - (assetSize.width - ((size.width/size.height) * assetSize.height))/2.0
                    }
                    else {
                        ytranslation = -(assetSize.height - ((size.height/size.width) * assetSize.width))/2.0
                    }
                    let translationTransform = CGAffineTransform(translationX: xtranslation, y: ytranslation)
                    
                    // Final transformation - Concatination
                    let finalTransform = defaultTransfrom.concatenating(rotateTransform).concatenating(translationTransform).concatenating(scaleTransform)
                    layerInstruction.setTransform(finalTransform, at: CMTime.zero)
                }
                
                instructionLayers.append(layerInstruction)
            }
            
            /// Adding audio
            if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                let aTrack = mixComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
                try? aTrack?.insertTimeRange(timeRange, of: audioTrack, at: startAt)
            }
            
            // Increase the startAt time
            startAt = CMTimeAdd(startAt, asset.duration)
        }
        
    
        
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: videos[0].duration)
        mainInstruction.layerInstructions = instructionLayers
        
        let mainCompositionInst = AVMutableVideoComposition()
        mainCompositionInst.instructions = [mainInstruction]
        mainCompositionInst.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainCompositionInst.renderSize = size
   
        let exportURL = writingPath
        
        
        let url = exportURL
        try? FileManager.default.removeItem(at: url)
        
        let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHEVCHighestQuality)
        exporter?.outputURL = url
        exporter?.outputFileType = .mp4
        exporter?.timeRange = timeRange
        exporter?.videoComposition = mainCompositionInst
        exporter?.shouldOptimizeForNetworkUse = true
        exporter?.exportAsynchronously(completionHandler: {
            if let anError = exporter?.error {
                complete(false)
            }
            else if exporter?.status == AVAssetExportSession.Status.completed {
                complete(true)
            }
        })
    }
}

//
//  VideoProcessing.swift
//  Runner
//
//  Created by Kapil Soni on 10/12/21.
//

import Foundation
import AVFoundation
class OverLayCommands{
    func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset, standardSize:CGSize, atTime: CMTime) -> AVMutableVideoCompositionLayerInstruction {
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            let assetTrack = asset.tracks(withMediaType: AVMediaType.video)[0]

            let transform = assetTrack.preferredTransform
            let assetInfo = orientationFromTransform(transform: transform)

            var aspectFillRatio:CGFloat = 1
            if assetTrack.naturalSize.height < assetTrack.naturalSize.width {
                aspectFillRatio = standardSize.height / assetTrack.naturalSize.height
            }
            else {
                aspectFillRatio = standardSize.width / assetTrack.naturalSize.width
            }

            if assetInfo.isPortrait {
                let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)

                let posX = standardSize.width/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
                let posY = standardSize.height/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
                let moveFactor = CGAffineTransform(translationX: posX, y: posY)

                instruction.setTransform(assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor), at: atTime)

            } else {
                let scaleFactor = CGAffineTransform(scaleX: aspectFillRatio, y: aspectFillRatio)

                let posX = standardSize.width/2 - (assetTrack.naturalSize.width * aspectFillRatio)/2
                let posY = standardSize.height/2 - (assetTrack.naturalSize.height * aspectFillRatio)/2
                let moveFactor = CGAffineTransform(translationX: posX, y: posY)

                var concat = assetTrack.preferredTransform.concatenating(scaleFactor).concatenating(moveFactor)

                if assetInfo.orientation == .down {
                    let fixUpsideDown = CGAffineTransform(rotationAngle: CGFloat(Double.pi))
                    concat = fixUpsideDown.concatenating(scaleFactor).concatenating(moveFactor)
                }

                instruction.setTransform(concat, at: atTime)
            }
            return instruction
        }
    func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImage.Orientation, isPortrait: Bool) {
        var assetOrientation = UIImage.Orientation.up
            var isPortrait = false
            if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
                assetOrientation = .right
                isPortrait = true
            } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
                assetOrientation = .left
                isPortrait = true
            } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
                assetOrientation = .up
            } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
                assetOrientation = .down
            }
            return (assetOrientation, isPortrait)
        }
    public func mergeStickerToVideo(
          videoPath: String,
        imageArrays:[StickerItem],writingPath:String,result: @escaping FlutterResult) {
            let screenSize: CGRect = UIScreen.main.bounds
            let screenWidth = screenSize.width
            let screenHeight = screenSize.height
           let videoUrl = URL(fileURLWithPath: videoPath)
           let videoUrlAsset = AVURLAsset(url: videoUrl, options: nil)
            var imageData = [UIImage]()
        var imageLayers = [CALayer]()
        for index in 0...imageArrays.count-1{
            print(imageArrays[index].imagePath)

            imageData.append(UIImage(contentsOfFile: imageArrays[index].imagePath )!)
        }
           // Setup `mutableComposition` from the existing video
           let mutableComposition = AVMutableComposition()
           let videoAssetTrack = videoUrlAsset.tracks(withMediaType: AVMediaType.video).first!
           let videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
           videoCompositionTrack?.preferredTransform = videoAssetTrack.preferredTransform
           try! videoCompositionTrack?.insertTimeRange(CMTimeRange(start:CMTime.zero, duration:videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: CMTime.zero)

        let audioTracks = videoUrlAsset.tracks(withMediaType: AVMediaType.audio)

        let compositionAudioTrack:AVMutableCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!

        for audioTrack in audioTracks {
            try! compositionAudioTrack.insertTimeRange(audioTrack.timeRange, of: audioTrack, at: CMTime.zero)
        }
           let videoSize: CGSize = (videoCompositionTrack?.naturalSize)!
        let frame = CGRect(origin: .zero, size: videoSize)
            let window = UIApplication.shared.windows[0]
            let topPadding = window.safeAreaInsets.top
            let xRatio = videoSize.width/screenWidth
            let yRatio = videoSize.height/screenHeight
        for index in 0...imageArrays.count-1{

                   let layer = CALayer()
                   layer.contents =  imageData[index].cgImage
                   layer.frame =  CGRect(x: imageArrays[index].x * Double(xRatio) , y: Double(CGFloat(imageArrays[index].y) * yRatio + topPadding), width:355*imageArrays[index].scale, height:355*imageArrays[index].scale)
                   imageLayers.append(layer)

               }

        let videoLayer = CALayer()
           videoLayer.frame = frame
           let animationLayer = CALayer()
           animationLayer.frame = frame
        animationLayer.isGeometryFlipped = true

           animationLayer.addSublayer(videoLayer)

        for index in 0...imageArrays.count-1{
            animationLayer.addSublayer(imageLayers[index])
        }
           let videoComposition = AVMutableVideoComposition(propertiesOf: (videoCompositionTrack?.asset!)!)
           videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: animationLayer)

        let exportURL = URL.init(fileURLWithPath: writingPath)


           let exportSession = AVAssetExportSession( asset: mutableComposition, presetName: AVAssetExportPresetHEVCHighestQuality)!

          exportSession.videoComposition = videoComposition
           exportSession.outputURL = exportURL
           exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                result(true)
            case .failed:
                print("failed \(String(describing: exportSession.error.debugDescription))")
                result(false)
            case .cancelled:
                print("cancelled \(String(describing: exportSession.error.debugDescription))")
                result(false)
            default:
                break
            }



        }

       }
    public func mergeTextToVideo(
          videoPath: String,
        imageArrays:[TextItem],writingPath:String,result: @escaping FlutterResult) {

           let videoUrl = URL(fileURLWithPath: videoPath)
           let videoUrlAsset = AVURLAsset(url: videoUrl, options: nil)
            var imageData = [UIImage]()
        var imageLayers = [CALayer]()
        for index in 0...imageArrays.count-1{
            print(imageArrays[index].imagePath)

            imageData.append(UIImage(contentsOfFile: imageArrays[index].imagePath )!)
        }
           // Setup `mutableComposition` from the existing video
           let mutableComposition = AVMutableComposition()
           let videoAssetTrack = videoUrlAsset.tracks(withMediaType: AVMediaType.video).first!
           let videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
           videoCompositionTrack?.preferredTransform = videoAssetTrack.preferredTransform
           try! videoCompositionTrack?.insertTimeRange(CMTimeRange(start:CMTime.zero, duration:videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: CMTime.zero)

        let audioTracks = videoUrlAsset.tracks(withMediaType: AVMediaType.audio)

        let compositionAudioTrack:AVMutableCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!

        for audioTrack in audioTracks {
            try! compositionAudioTrack.insertTimeRange(audioTrack.timeRange, of: audioTrack, at: CMTime.zero)
        }
           let videoSize: CGSize = (videoCompositionTrack?.naturalSize)!
        let frame = CGRect(origin: .zero, size: videoSize)


        for index in 0...imageArrays.count-1{
            print("X Positions:",imageArrays[index].x)
            print("Y Positions:",imageArrays[index].y)
            let layer = CALayer()
            layer.contents =  imageData[index].cgImage
            layer.frame =  CGRect(x: imageArrays[index].x, y: imageArrays[index].y, width:imageArrays[index].width, height:imageArrays[index].height)
            imageLayers.append(layer)

        }

        let videoLayer = CALayer()
           videoLayer.frame = frame
           let animationLayer = CALayer()
           animationLayer.frame = frame
        animationLayer.isGeometryFlipped = true

           animationLayer.addSublayer(videoLayer)

        for index in 0...imageArrays.count-1{
            animationLayer.addSublayer(imageLayers[index])
        }
           let videoComposition = AVMutableVideoComposition(propertiesOf: (videoCompositionTrack?.asset!)!)
           videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: animationLayer)

        let exportURL = URL.init(fileURLWithPath: writingPath)


           let exportSession = AVAssetExportSession( asset: mutableComposition, presetName: AVAssetExportPresetHEVCHighestQuality)!

          exportSession.videoComposition = videoComposition
           exportSession.outputURL = exportURL
           exportSession.outputFileType = AVFileType.mp4
        exportSession.shouldOptimizeForNetworkUse = false
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                result(true)
            case .failed:
                print("failed \(String(describing: exportSession.error.debugDescription))")
                result(false)
            case .cancelled:
                print("cancelled \(String(describing: exportSession.error.debugDescription))")
                result(false)
            default:
                break
            }



        }

       }
}

//  CoreVideoCommands.swift
//  Runner
//
//  Created by Kapil on 10/12/21.
//

import Foundation
import AVFoundation
class VideoMerging{
    
    func merge(finalPath:String,arrayUrl:[String],result: @escaping FlutterResult) {
                var arrayVideos = [AVAsset]()
                //let defaultSize = CGSize(width: 1920, height: 1080)
                for index in 0...arrayUrl.count-1{
                            arrayVideos.append(AVURLAsset(url: URL(fileURLWithPath: arrayUrl[index]),options:[AVURLAssetPreferPreciseDurationAndTimingKey:true]))
                        }
              let mainComposition = AVMutableComposition()
              let compositionVideoTrack = mainComposition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID())
                compositionVideoTrack?.preferredTransform = .identity

              let soundtrackTrack = mainComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID())

            var insertTime = CMTime(value: 0, timescale: 600, flags: CMTimeFlags(rawValue: 1), epoch: 0)
                var timeRange:CMTimeRange
                var difference:CMTime
                var data = 0.0
              for videoAsset in arrayVideos {
                  difference = CMTimeSubtract(videoAsset.tracks(withMediaType: .video)[0].timeRange.duration, videoAsset.tracks(withMediaType: .audio)[0].timeRange.duration)
                  print("Video Duration",videoAsset.tracks(withMediaType: .video)[0].timeRange.duration)
                  print("Audio Duration",videoAsset.tracks(withMediaType: .audio)[0].timeRange.duration)
                  data = data + abs(difference.seconds)
                  timeRange =  CMTimeRangeGetIntersection(videoAsset.tracks(withMediaType: .video)[0].timeRange, otherRange: videoAsset.tracks(withMediaType: .audio)[0].timeRange)

                  try! compositionVideoTrack?.insertTimeRange(timeRange, of: videoAsset.tracks(withMediaType: .video)[0], at: insertTime)
                try! soundtrackTrack?.insertTimeRange(timeRange, of: videoAsset.tracks(withMediaType: .audio)[0], at: insertTime)
                  insertTime = CMTimeAdd(insertTime,timeRange.duration)
                  print("FinalDuration",insertTime)
              }

            let outputFileURL = URL.init(fileURLWithPath: finalPath)

              let exporter = AVAssetExportSession(asset: mainComposition, presetName: AVAssetExportPresetHEVCHighestQuality)

              exporter?.outputURL = outputFileURL
              exporter?.outputFileType = AVFileType.mp4
              exporter?.shouldOptimizeForNetworkUse = false
              exporter?.exportAsynchronously {
                  switch exporter!.status {
                  case .completed:
                      result(true)
                  case .failed:
                      print("failed \(String(describing: exporter?.error.debugDescription))")
                      result(false)
                  case .cancelled:
                      print("cancelled \(String(describing: exporter?.error.debugDescription))")
                      result(false)
                  default:
                      break
                  }
              }
            }
}
class SpeedCommand{
    
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
    
    func timeLapseVideo(urlPath:String,speed:Float,finalPath:String, result: @escaping FlutterResult){
        //Generating Video Assets
       // let videoAsset = AVURLAsset(url:url)
        let url = URL(fileURLWithPath: urlPath)
        let videoAsset = AVURLAsset(url: url,options:[AVURLAssetPreferPreciseDurationAndTimingKey:true])
        //Declaring Composition
        let comp = AVMutableComposition()

        //Getting tracks of video and audio
        let videoAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        // Silence sound (in case of video has no sound track)
        let silenceURL = Bundle.main.url(forResource: "captain", withExtension: "mp3")
        let silenceAsset = AVAsset(url:silenceURL!)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first

        var audioAssetSourceTrack:AVAssetTrack?
        if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            audioAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first
        }
        else {
            audioAssetSourceTrack = silenceSoundTrack
        }
    //    let audioAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first! as AVAssetTrack

        //Making Composition tracks
        let videoCompositionTrack = comp.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioCompositionTrack = comp.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        do {
            //inserting time range for video from video duration
            try videoCompositionTrack!.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration),
                of: videoAssetSourceTrack,
                at: CMTime.zero)
            //inserting time range for audio from video duration this is used to sync both duration
            try audioCompositionTrack!.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration),
                of: audioAssetSourceTrack!,
                at: CMTime.zero)
            //Initializing scaleFactor/Speed preset
            let videoScaleFactor = Int64(speed)
            //Duration
            let videoDuration: CMTime = videoAsset.duration

            //Composition to give final ouput of video according to the speed
            videoCompositionTrack!.scaleTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoDuration), toDuration: CMTimeMake(value: videoDuration.value * 1/(videoScaleFactor), timescale: videoDuration.timescale))
            //Composition to give final ouput of audio according to the speed
            audioCompositionTrack!.scaleTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoDuration), toDuration: CMTimeMake(value: videoDuration.value * 1/(videoScaleFactor), timescale: videoDuration.timescale))
            videoCompositionTrack!.preferredTransform = videoAssetSourceTrack.preferredTransform


            //making output path
            let outputFileURL = URL(fileURLWithPath:finalPath)



            //Exporter configs
            let exporter = AVAssetExportSession(asset:comp, presetName: AVAssetExportPresetHEVCHighestQuality)
           // exporter?.presetName = .availableStringEncodings
            exporter?.outputURL = outputFileURL
              exporter?.outputFileType = AVFileType.mp4
            exporter?.shouldOptimizeForNetworkUse = false

            exporter?.exportAsynchronously {
                switch exporter!.status {
                case .completed:
                    result(true)
                case .failed:
                    print("failed \(String(describing: exporter?.error.debugDescription))")
                    result(false)
                case .cancelled:
                    print("cancelled \(String(describing: exporter?.error.debugDescription))")
                    result(false)
                default:
                    break
                }



            }


        }catch { print(error) }

    }
    func slowMotionVideo(urlPath:String,speed:Float,finalPath:String, result: @escaping FlutterResult){
        //Generating Video Assets
       // let videoAsset = AVURLAsset(url:url)
       let url = URL(fileURLWithPath: urlPath)
        let videoAsset = AVURLAsset(url: url,options:[AVURLAssetPreferPreciseDurationAndTimingKey:true])
        //Declaring Composition
        let comp = AVMutableComposition()

        //Getting tracks of video and audio
        let videoAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        // Silence sound (in case of video has no sound track)
        let silenceURL = Bundle.main.url(forResource: "captain", withExtension: "mp3")
        let silenceAsset = AVAsset(url:silenceURL!)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first

        var audioAssetSourceTrack:AVAssetTrack?
        if videoAsset.tracks(withMediaType: AVMediaType.audio).count > 0 {
            audioAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first! as AVAssetTrack
        }
        else {
            audioAssetSourceTrack = silenceSoundTrack
        }
    //    let audioAssetSourceTrack = videoAsset.tracks(withMediaType: AVMediaType.audio).first! as AVAssetTrack

        //Making Composition tracks
        let videoCompositionTrack = comp.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioCompositionTrack = comp.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        do {
            //inserting time range for video from video duration
            try videoCompositionTrack!.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration),
                of: videoAssetSourceTrack,
                at: CMTime.zero)
            //inserting time range for audio from video duration this is used to sync both duration
            try audioCompositionTrack!.insertTimeRange(
                CMTimeRangeMake(start: CMTime.zero, duration: videoAsset.duration),
                of: audioAssetSourceTrack!,
                at: CMTime.zero)
            //Initializing scaleFactor/Speed preset
            let videoScaleFactor = Int64(speed)
            //Duration
            let videoDuration: CMTime = videoAsset.duration

            //Composition to give final ouput of video according to the speed
            videoCompositionTrack!.scaleTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoDuration), toDuration: CMTimeMake(value: videoDuration.value * videoScaleFactor, timescale: videoDuration.timescale))
            //Composition to give final ouput of audio according to the speed
            audioCompositionTrack!.scaleTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: videoDuration), toDuration: CMTimeMake(value: videoDuration.value * videoScaleFactor, timescale: videoDuration.timescale))
            videoCompositionTrack!.preferredTransform = videoAssetSourceTrack.preferredTransform


            //making output path
            let outputFileURL = URL(fileURLWithPath: finalPath)

            let fileManager = FileManager()
            try? fileManager.removeItem(at: outputFileURL)

            //Exporter configs
            let exporter = AVAssetExportSession(asset:comp, presetName: AVAssetExportPresetHEVCHighestQuality)

            exporter?.outputURL = outputFileURL
              exporter?.outputFileType = AVFileType.mp4
            exporter?.shouldOptimizeForNetworkUse = false

            exporter?.exportAsynchronously {
                switch exporter!.status {
                case .completed:
                    result(true)
                case .failed:
                    print("failed \(String(describing: exporter?.error.debugDescription))")
                    result(false)
                case .cancelled:
                    print("cancelled \(String(describing: exporter?.error.debugDescription))")
                    result(false)
                default:
                    break
                }



            }


        }catch { print(error) }

    }
}

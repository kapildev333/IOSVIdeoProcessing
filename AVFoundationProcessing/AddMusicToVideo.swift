import AVFoundation

open class AddBackGroundMusic {
    public init() {}
}

public extension AddBackGroundMusic {
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
    func merge(video: AddBackGroundMusic.Asset, audioStartTime:CMTime,audios: [AddBackGroundMusic.Asset],writingPath:String,
               progress: ((Float) -> Void)?,
               completion: @escaping (Result<URL, Error>) -> Void) {

        // Create Asset from record and music
        let videoAsset = AVURLAsset(url: video.localURL)
        let audioAssets = audios.map { AVURLAsset(url: $0.localURL) }
        var insertTime = CMTime.zero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        var outputSize = CGSize.init(width: 0, height: 0)
        let silenceURL = Bundle.main.url(forResource: "captain", withExtension: "mp3")
        let silenceAsset = AVAsset(url:silenceURL!)
        let silenceSoundTrack = silenceAsset.tracks(withMediaType: AVMediaType.audio).first
        var createdAudioTrack = silenceSoundTrack
        if(videoAsset.tracks(withMediaType: .audio).count>0){
            createdAudioTrack = videoAsset.tracks(withMediaType: .audio)[safe: 0]! as AVAssetTrack
        }
        let videoTimeRange = video.timeRange
        let duration = videoAsset.duration
        // Create compositions
        let mixComposition = AVMutableComposition()
        let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        guard let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID()) else {
            return
        }

        if(videoAsset.tracks(withMediaType: .audio).count>0){
          let audioInVideoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID())
            do {
                // Add original audio to final record
                try audioInVideoCompositionTrack!.insertTimeRange(videoTimeRange, of: createdAudioTrack!, at: .zero)
                // Adjust volume
                let videoAudioParams = AVMutableAudioMixInputParameters(track: createdAudioTrack)
                videoAudioParams.trackID = audioInVideoCompositionTrack!.trackID
                videoAudioParams.setVolumeRamp(fromStartVolume: video.volume, toEndVolume: video.volume, timeRange: videoTimeRange)
                audioMixParams.append(videoAudioParams)
            } catch {
                completion(.failure(error))
                return
            }
        }

        let audioCompositionTrack = audios.compactMap { _ in mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID()) }

        // Create tracks createdAudioTrack
    

        let audioAssetTracks = audioAssets.compactMap { $0.tracks(withMediaType: .audio)[safe: 0] }

        guard audioCompositionTrack.count == audioAssetTracks.count,
              audioCompositionTrack.count == audios.count else {
            return
        }

       
        let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
        var videoSize = videoTrack.naturalSize
        if assetInfo.isPortrait == true {
            videoSize.width = videoTrack.naturalSize.height
            videoSize.height = videoTrack.naturalSize.width
        }

        if videoSize.height > outputSize.height {
            outputSize = videoSize
        }
        // Add video to the final record
        do {
            let track = videoAsset.tracks(withMediaType: .video)[0]
            try videoCompositionTrack.insertTimeRange(videoTimeRange, of: track, at: .zero)
        } catch {
            print(error)
            completion(.failure(error))
            return
        }

      

        //
        // Add audios to final record
        for i in 0..<audios.count {
            do {
                let timeRange = CMTimeRange(start: audioStartTime, duration: videoAsset.duration)
                try audioCompositionTrack[i].insertTimeRange(timeRange, of: audioAssetTracks[i], at: audios[i].startTime)

                // Adjust volume
                let audioParams = AVMutableAudioMixInputParameters(track: audioAssetTracks[i])
                audioParams.trackID = audioCompositionTrack[i].trackID
                audioParams.setVolumeRamp(fromStartVolume: audios[i].volume, toEndVolume: audios[0].volume, timeRange: timeRange)
                audioMixParams.append(audioParams)
                
            } catch {
                completion(.failure(error))
                return
            }
        }
        let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack,
                                                                   asset: videoAsset,
                                                                   standardSize: outputSize,
                                                                   atTime: insertTime)

        arrayLayerInstructions.append(layerInstruction)

        // Increase the insert time
        insertTime = CMTimeAdd(insertTime, duration)
        audioMix.inputParameters = audioMixParams

        let outputVideoLocalURL =  URL.init(fileURLWithPath: writingPath)

        let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
    
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
    mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = outputSize
        //Export the final record
        let session = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHEVCHighestQuality)!
        session.shouldOptimizeForNetworkUse = false
        session.outputURL = outputVideoLocalURL
        session.outputFileType = .mp4
        session.audioMix = audioMix
        session.videoComposition = mainComposition
        session.exportAsynchronously {
            switch session.status {
            case .completed:
                print("success")
                DispatchQueue.main.async {
                    completion(.success(outputVideoLocalURL))
                }
            case .failed:
                print("failed")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .cancelled:
                print("cancelled")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting...")
            case .exporting:
                progress?(session.progress)
            @unknown default:
                print("unknown")
            }
        }
    }
    func removeAudio(video: AddBackGroundMusic.Asset, writingPath:String ,progress: ((Float) -> Void)?,
                     completion: @escaping (Result<URL, Error>) -> Void){
        let videoAsset = AVURLAsset(url: video.localURL)
        var insertTime = CMTime.zero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []

        var outputSize = CGSize.init(width: 0, height: 0)
        let videoTimeRange = video.timeRange
        let duration = videoAsset.duration
        // Create compositions
        let mixComposition = AVMutableComposition()
        let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        guard let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID()) else {
            return
        }
        
         let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
         var videoSize = videoTrack.naturalSize
         if assetInfo.isPortrait == true {
             videoSize.width = videoTrack.naturalSize.height
             videoSize.height = videoTrack.naturalSize.width
         }

         if videoSize.height > outputSize.height {
             outputSize = videoSize
         }
         // Add video to the final record
         do {
             let track = videoAsset.tracks(withMediaType: .video)[0]
             try videoCompositionTrack.insertTimeRange(videoTimeRange, of: track, at: .zero)
         } catch {
             print(error)
             completion(.failure(error))
             return
         }
        let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack,
                                                                   asset: videoAsset,
                                                                   standardSize: outputSize,
                                                                   atTime: insertTime)

        arrayLayerInstructions.append(layerInstruction)

        // Increase the insert time
        insertTime = CMTimeAdd(insertTime, duration)

        let outputVideoLocalURL = URL.init(fileURLWithPath: writingPath)

        let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
    mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = outputSize
        //Export the final record
        let session = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHEVCHighestQuality)!
        session.shouldOptimizeForNetworkUse = false
        session.outputURL = outputVideoLocalURL
        session.outputFileType = .mp4
        session.videoComposition = mainComposition
        session.exportAsynchronously {
            switch session.status {
            case .completed:
                print("success")
                DispatchQueue.main.async {
                    completion(.success(outputVideoLocalURL))
                }
            case .failed:
                print("failed")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .cancelled:
                print("cancelled")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting...")
            case .exporting:
                progress?(session.progress)
            @unknown default:
                print("unknown")
            }
        }
    }
    func adjustVideoVolume(video: AddBackGroundMusic.Asset,writingPath:String,progress: ((Float) -> Void)?,
                           completion: @escaping (Result<URL, Error>) -> Void){
        let videoAsset = AVURLAsset(url: video.localURL)
        var insertTime = CMTime.zero
        var arrayLayerInstructions:[AVMutableVideoCompositionLayerInstruction] = []
        let audioMix = AVMutableAudioMix()
        var audioMixParams: [AVMutableAudioMixInputParameters] = []
        var outputSize = CGSize.init(width: 0, height: 0)
        var containsAudio = true
        let videoTimeRange = video.timeRange
        let duration = videoAsset.duration
        // Create compositions
        let mixComposition = AVMutableComposition()
        let videoTrack = videoAsset.tracks(withMediaType: AVMediaType.video).first! as AVAssetTrack
        guard let videoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID()) else {
            return
        }
        guard let createdAudioTrack = videoAsset.tracks(withMediaType: .audio)[safe: 0] else {
            containsAudio = false
            completion(.failure(VideoEditorError.notFoundAudioInVideo))
            return
        }
        
         let assetInfo = orientationFromTransform(transform: videoTrack.preferredTransform)
         var videoSize = videoTrack.naturalSize
         if assetInfo.isPortrait == true {
             videoSize.width = videoTrack.naturalSize.height
             videoSize.height = videoTrack.naturalSize.width
         }

         if videoSize.height > outputSize.height {
             outputSize = videoSize
         }
         // Add video to the final record
         do {
             let track = videoAsset.tracks(withMediaType: .video)[0]
             try videoCompositionTrack.insertTimeRange(videoTimeRange, of: track, at: .zero)
         } catch {
             print(error)
             completion(.failure(error))
             return
         }
        if(videoAsset.tracks(withMediaType: .audio).count>0){
            guard let audioInVideoCompositionTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID()) else {
                completion(.failure(VideoEditorError.notFoundAudioInVideo))
                return
            }
            do {
                // Add original audio to final record
                try audioInVideoCompositionTrack.insertTimeRange(videoTimeRange, of: createdAudioTrack, at: .zero)
                // Adjust volume
                let videoAudioParams = AVMutableAudioMixInputParameters(track: createdAudioTrack)
                videoAudioParams.trackID = audioInVideoCompositionTrack.trackID
                videoAudioParams.setVolumeRamp(fromStartVolume: video.volume, toEndVolume: video.volume, timeRange: videoTimeRange)
                audioMixParams.append(videoAudioParams)
            } catch {
                completion(.failure(error))
                return
            }
        }
        let layerInstruction = videoCompositionInstructionForTrack(track: videoCompositionTrack,
                                                                   asset: videoAsset,
                                                                   standardSize: outputSize,
                                                                   atTime: insertTime)

        arrayLayerInstructions.append(layerInstruction)

        // Increase the insert time
        insertTime = CMTimeAdd(insertTime, duration)

        let outputVideoLocalURL = URL(fileURLWithPath: writingPath)

        let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: insertTime)
        mainInstruction.layerInstructions = arrayLayerInstructions
        if(containsAudio){
            audioMix.inputParameters = audioMixParams
        }
        // Main video composition
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
    mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = outputSize
        //Export the final record
        let session = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHEVCHighestQuality)!
        session.shouldOptimizeForNetworkUse = false
        session.outputURL = outputVideoLocalURL
        session.outputFileType = .mp4
        session.videoComposition = mainComposition
        if(containsAudio){
            session.audioMix = audioMix
        }
        session.exportAsynchronously {
            switch session.status {
            case .completed:
                print("success")
                DispatchQueue.main.async {
                    completion(.success(outputVideoLocalURL))
                }
            case .failed:
                print("failed")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .cancelled:
                print("cancelled")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting...")
            case .exporting:
                progress?(session.progress)
            @unknown default:
                print("unknown")
            }
        }
    }
    
}

// MARK: - Privates
extension AddBackGroundMusic {
    private func makeOutputURL() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "merged-video.mp4")
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print(error.localizedDescription)
        }
        return url
    }

    private func export(with session: AVAssetExportSession,
                        progress: ((Float) -> Void)?,
                        completion: @escaping (Result<URL, Error>) -> Void) {
        let outputURL = makeOutputURL()
        session.outputURL = outputURL
        session.exportAsynchronously {
            switch session.status {
            case .completed:
                print("success")
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            case .failed:
                print("failed")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .cancelled:
                print("cancelled")
                guard let error = session.error else { return }
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            case .unknown:
                print("unknown")
            case .waiting:
                print("waiting...")
            case .exporting:
                progress?(session.progress)
            @unknown default:
                print("unknown")
            }
        }
    }
}

public extension AddBackGroundMusic {
    class Asset {
        public var localURL: URL
        public var volume: Float
        public var startTime: CMTime
        public var duration: CMTime

        /// Initialize asset add to composition
        /// - Parameters:
        ///   - localURL: The asset local URL
        ///   - volume: Volume of the asset will be adjusted to the final video
        ///   - startTime: The point of time that you wanna add your audio into the final video, e.g. add set `startTime` as `CMTime(seconds: 3, preferredTimescale: CMTimeScale(NSEC_PER_SEC))` to tell engine to start add this audio from the third second of the final video.
        ///   - duration: Indicates how long the audio will be added into the final video from the `startTime`. Usually set it equals to the audio's duration. Set `nil` to tell the `duration` is its duration.
        public init(localURL: URL, volume: Float = 1,
                    startTime: CMTime = .zero, duration: CMTime? = nil) {
            self.localURL = localURL
            self.volume = volume
            self.startTime = startTime
            self.duration = duration ?? localURL.localAssetDuration
        }

        public var timeRange: CMTimeRange {
            return CMTimeRange(start: startTime, duration: duration)
        }
    }
}

public enum VideoEditorError: Int, Error {
    case notFoundAudioInVideo = 10000
}

extension VideoEditorError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notFoundAudioInVideo:
            return NSLocalizedString("Cannot found audio in video!", comment: "")
        }
    }
}

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension URL {
    /// This work only with local asset
    var localAssetDuration: CMTime {
        let asset = AVAsset(url: self)
        return asset.duration
    }
}

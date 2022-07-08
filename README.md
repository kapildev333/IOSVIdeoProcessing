Hello Guys this is repo contains basic features of trimming , scaling video to perticular resolution by even maintaining aspectratio of video. It can also contains features such as merging audio to video by adjusting both video and audio volumes.You can also add multiple stickers to video.It also has commands for converting video to timelapse and slow motion.

        if(call.method == "gifCreation"){
                let videoURL   = URL(fileURLWithPath: ((arguments!["basePath"] as? String)!))
                let startTime = (arguments!["startTime"] as? NSNumber)!
                let duration  = (arguments!["duration"] as? NSNumber)!
                let frameRate = (arguments!["frameRate"] as? NSNumber)!
                let gifPath   = URL(fileURLWithPath: ((arguments!["gifPath"] as? String)!))
                var pathOfGif = [String]()
                gifCreation.createGIFFromSource(videoURL,destinationFileURL: gifPath,startTime: Float(truncating: startTime), duration:                 Float(truncating: duration),frameRate: Int(truncating: frameRate),size: CGSize(width: 240, height: 240)){ (result) in
                    pathOfGif.append(result!.path)
                    print("Gif saved to \(String(describing: result))")
                    
                }
                result(pathOfGif[0])
            }
            else if(call.method == "mergeStickerToVideo"){
                let objectOfOverlayCommand = OverLayCommands()
                var StickerItems = [StickerItem]()
                let   imageList = ((arguments!["imageArrays"] as? [String])!)
                let  scales = ((arguments!["scaleList"] as? [Double])!)
                let xCoordinates = (arguments!["xCoordinates"] as? [NSNumber])!
                let  yCoordinates = (arguments!["yCoordinates"] as? [NSNumber])!
                let writingPath = (arguments!["writingPath"] as? String)!
                print(imageList)
                for index in 0...imageList.count-1{
                    StickerItems.append(StickerItem(imageData: imageList[index], xData: Double(Int(truncating: xCoordinates[index])), yData: Double(Int(truncating: yCoordinates[index])), scaleData: scales[index] ))
                }
                
                objectOfOverlayCommand.mergeStickerToVideo(videoPath: (arguments!["videoPath"] as? String)!, imageArrays: StickerItems,writingPath:writingPath,result: result)
            }
            else if(call.method=="slowMotionVideo"){
                let objectOfSpeedCommand = SpeedCommand()
                objectOfSpeedCommand.slowMotionVideo(urlPath:(arguments!["urlPath"] as? String)!, speed: (arguments!["speed"] as? NSNumber)?.floatValue ?? 0,finalPath: (arguments!["writingPath"] as? String)!,result: result)
            }else if(call.method=="timeLapseVideo"){
                let objectOfSpeedCommand = SpeedCommand()
                objectOfSpeedCommand.timeLapseVideo(urlPath:(arguments!["urlPath"] as? String)! , speed: (arguments!["speed"] as? NSNumber)?.floatValue ?? 0,finalPath:(arguments!["writingPath"] as? String)! ,result: result)
            }
            else if(call.method=="cropVideo"){
                let videoURL   = URL(fileURLWithPath: ((arguments!["videoPath"] as? String)!))
                let destinationURL   = URL(fileURLWithPath: ((arguments!["destinationURL"] as? String)!))
                let  startTime = ((arguments!["startValue"] as? NSNumber)!)
                let  endTime = ((arguments!["endValue"] as? NSNumber)!)
                let objectOfVideoTrimmer = VideoTrimming()
                objectOfVideoTrimmer.trimmingVideo(videoAsset: AVURLAsset(url: videoURL,options: [AVURLAssetPreferPreciseDurationAndTimingKey:true]), animation: false, startTimeInSeconds: Double(truncating: startTime), endTimeInSeconds: Double(truncating: endTime), writingPath: destinationURL){ (success) in
                    DispatchQueue.main.async {
                        if success {
                            result(true)
                        }else {
                            result(false)
                        }
                    }
                }
                
            }
            else if(call.method=="Merge"){
                let objectOfVideoMerging = VideoMerging()
                objectOfVideoMerging.merge(finalPath:  (arguments!["writingPath"] as? String)!, arrayUrl: (arguments!["urlPath"] as? [String])!, result: result)
            }
            else if (call.method=="removeAudio"){
                let originalVideoPath = URL(fileURLWithPath: (arguments!["videoPath"] as? String)!)
                let writingUrl =  URL(fileURLWithPath: (arguments!["writingPath"] as? String)!)
                let assetFromUrl =  AVURLAsset(url: originalVideoPath, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                let musicobj = MusicCommand()
                musicobj.removeAudio(videos: [assetFromUrl], writingPath: writingUrl, result: result)
                
            }
            else if (call.method=="addMusicToVideo"){
                let originalVideoPath = URL(fileURLWithPath: (arguments!["videoPath"] as? String)!)
                let musicPath = URL(fileURLWithPath: (arguments!["musicPath"] as? String)!)
                let originalVideoVolume = ((arguments!["volume"] as? NSNumber)!)
                let musicVolume = ((arguments!["musicVolume"] as? NSNumber)!)
                let  musicStartValue = ((arguments!["musicStartValue"] as? NSNumber)!)
                let startCMtime = CMTime(seconds: Double(musicStartValue), preferredTimescale: 600)
                let writingUrl =  URL(fileURLWithPath: (arguments!["writingPath"] as? String)!)
                let assetFromUrl =  AVURLAsset(url: originalVideoPath, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                let videoAsset = MusicCommand.Asset(localURL: originalVideoPath, volume: Float(originalVideoVolume))
                let musicAsset = MusicCommand.Asset(localURL: musicPath, volume: Float(musicVolume))
                let musicobj = MusicCommand()
                musicobj.mergeMusic(videos: [assetFromUrl], writingPath: writingUrl, video: videoAsset, audios: [musicAsset], audioStartTime: startCMtime, result: result)
                
            }
            else if (call.method=="adjustVideoVolume"){
                let originalVideoPath = URL(fileURLWithPath: (arguments!["videoPath"] as? String)!)
                let originalVideoVolume = ((arguments!["volume"] as? NSNumber)!)
                let writingUrl =  URL(fileURLWithPath: (arguments!["writingPath"] as? String)!)
                let assetFromUrl =  AVURLAsset(url: originalVideoPath, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                let musicAsset = MusicCommand.Asset(localURL: originalVideoPath, volume: Float(originalVideoVolume))
                let musicobj = MusicCommand()
                musicobj.adjustVideoVolume(videos: [assetFromUrl], writingPath: writingUrl, video: musicAsset,result: result)
                
            }
            else if(call.method=="scaleVideo"){
                let objectScaling = VideoScaling()
                let originalPath = URL(fileURLWithPath: (arguments!["videoPath"] as? String)!)
                let asset = AVURLAsset(url: originalPath, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                let writingUrl = URL(fileURLWithPath: (arguments!["destinationURL"] as? String)!)
                let  startTime = ((arguments!["startValue"] as? NSNumber)!)
                let  endTime = ((arguments!["endValue"] as? NSNumber)!)
                objectScaling.scaleVideo(videos: [asset], startTimeInSeconds: Double(truncating: startTime), endTimeInSeconds: Double(endTime), writingPath: writingUrl,complete:result)
            }
            else if(call.method=="thumbCreation"){
                let obj = ThumbGeneration()
                let originalPath = URL(fileURLWithPath: (arguments!["videoPath"] as? String)!)
                let  timeMS = ((arguments!["timeMS"] as? NSNumber)!)
                let  numberOfThumb = ((arguments!["numberOfThumb"] as? NSNumber)!)
                
                ///running function on background thread
                DispatchQueue.global(qos: .background).async {
                    let data =   obj.thumbGeneratiion(url:originalPath,timeMS:Double(timeMS),numberOfThumb:Double(Int(numberOfThumb)))
                    result(data)
                }
            }
            
        class StickerItem
        {
            var scale = 0.0
            var imagePath = ""
            var x = 0.0
            var y = 0.0
            var id = 0.0
            var rotation = 0
            init(imageData:String,xData:Double,yData:Double,scaleData:Double) {
                self.id = 0.0;
                self.imagePath = imageData;
                self.rotation = Int(0.0);
                self.x = xData;
                self.y = yData;
                self.scale = scaleData;
            }
        }
        class TextItem
        {
            var width = 0.0
            var imagePath = ""
            var x = 0.0
            var y = 0.0
            var id = 0.0
            var height = 0.0
            init(imageData:String,xData:Double,yData:Double,widthData:Double,heightData:Double) {
                self.id = 0.0;
                self.imagePath = imageData;
                self.width = widthData;
                self.x = xData;
                self.y = yData;
                self.height = heightData;
            }
        }

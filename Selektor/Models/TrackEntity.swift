//
//  TrackEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import CoreData

enum AnalysisState: Int {
  case toDo = 0
  case inProgress
  case complete
}

@objc(TrackEntity)
class TrackEntity: SelektorObject {
  override class func getEntityName() -> String {
    return "Track"
  }

  static let mirexPath: String? = NSBundle.mainBundle().pathForResource("mirex_extract",
    ofType: nil, inDirectory: "Lib/marsyas/bin")
  static let ffmpegPath: String? = NSBundle.mainBundle().pathForResource("ffmpeg",
      ofType: nil, inDirectory: "Lib/ffmpeg")
  static let tempoPath: String? = NSBundle.mainBundle().pathForResource("tempo",
    ofType: nil, inDirectory: "Lib/marsyas/bin")

  // MARK: Properties
  @NSManaged dynamic var analyzed: NSNumber
  @NSManaged dynamic var duration: NSNumber?
  @NSManaged dynamic var filename: String?
  @NSManaged dynamic var loudness: NSNumber?
  @NSManaged dynamic var tempo: NSNumber?
  @NSManaged dynamic var album: String?
  @NSManaged dynamic var artist: String?
  @NSManaged dynamic var genre: String?
  @NSManaged dynamic var key: String?
  @NSManaged dynamic var timbreVectors: NSSet?

  let tempDirectory = NSURL(fileURLWithPath: NSTemporaryDirectory() as String)

  // MARK: Convenience properties

  dynamic var relativeFilename: String? {
    return NSURL(fileURLWithPath: self.filename!).lastPathComponent ?? nil
  }

  dynamic var timbreVector64: [Double] {
    get {
      if self.analyzed != AnalysisState.complete.rawValue {
        return [Double](count: 64, repeatedValue: 0.0)
      }

      var vector: [Double] = []
      vector += self.mammTimbre!.vector
      vector += self.masmTimbre!.vector
      vector += self.sammTimbre!.vector
      vector += self.sasmTimbre!.vector

      return vector
    }
  }

  dynamic var timbreVectorSet: NSMutableSet {
    return self.mutableSetValueForKey("timbreVectors")
  }

  dynamic var mammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.meanAccMeanMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.meanAccMeanMem) }
  }

  dynamic var masmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.meanAccStdMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.meanAccStdMem) }
  }

  dynamic var sammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.stdAccMeanMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.stdAccMeanMem) }
  }

  dynamic var sasmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreVector(forSummaryType: SummaryType.stdAccStdMem) }
    set { self.setTimbreVector(newValue!, forSummaryType: SummaryType.stdAccStdMem) }
  }

  // MARK: Convenience getter and setter functions for retrieving/storing timbre vectors
  // of a given summary type

  func getTimbreVector(forSummaryType summaryType: SummaryType) -> TimbreVectorEntity? {
    return timbreVectorSet.filter({
      ($0 as! TimbreVectorEntity).summaryType == summaryType.rawValue
    }).first as? TimbreVectorEntity
  }

  func removeTimbreVector(forSummaryType summaryType: SummaryType) {
    if let oldVector = self.getTimbreVector(forSummaryType: summaryType) {
      // Remove the old vector for the summary type
      timbreVectorSet.removeObject(oldVector)
    }
  }

  func setTimbreVector(newVector: TimbreVectorEntity, forSummaryType summaryType: SummaryType) {
    // Remove old timbre vector if necessary
    self.removeTimbreVector(forSummaryType: summaryType)

    // Set the summary type for the new vector and add it to the timbres set
    newVector.summaryType = summaryType.rawValue
    timbreVectorSet.addObject(newVector)
  }

  func compareTimbreWith(otherTrack track: TrackEntity) -> Double {
    let formula = self.appDelegate.settings?["distanceFormula"] as! String
    return self.timbreVector64.calculateDistanceFrom(
      otherVector: track.timbreVector64, withFormula: formula)
  }

  // MARK: Analysis Functions

  func createTimbreVector(fromFeaturesArray features: [Double]) -> TimbreVectorEntity {
    let vector: TimbreVectorEntity = self.dataController.createEntity()

    vector.centroid = features[0]
    vector.rolloff = features[1]
    vector.flux = features[2]
    vector.mfcc = Array(features[3...11])

    return vector
  }

  func store64DimensionalTimbreVector(arffFileURL: NSURL) {
    do {
      let arffContents = try String(contentsOfURL: arffFileURL)
      let arffLines = arffContents.componentsSeparatedByString("\n")

      // Extract the vector from the ARFF file.
      // Since only one track was analyzed, only one vector will be contained
      // in the file, so we always know the position of the vector relative to
      // the end of the file.
      let vectorString = arffLines[arffLines.endIndex - 2]
      var stringFeatures = vectorString.componentsSeparatedByString(",")
      stringFeatures.removeLast() // Remove the file label
      let features = (stringFeatures.map({ Double($0)! }) as [Double]) // Cast strings to doubles

      // Split array into 16-dimensional vectors for each summary type
      let mammFeatures = Array(features[0...15])
      let masmFeatures = Array(features[16...31])
      let sammFeatures = Array(features[32...47])
      let sasmFeatures = Array(features[48...63])

      // Set up vectors
      self.mammTimbre = self.createTimbreVector(fromFeaturesArray: mammFeatures)
      self.masmTimbre = self.createTimbreVector(fromFeaturesArray: masmFeatures)
      self.sammTimbre = self.createTimbreVector(fromFeaturesArray: sammFeatures)
      self.sasmTimbre = self.createTimbreVector(fromFeaturesArray: sasmFeatures)

    } catch {
      print("Error reading from ARFF file at \(arffFileURL)")
    }
  }

  func computeTimbre(wavURL: NSURL) {
    guard let mirexPath = TrackEntity.mirexPath else {
      print("Unable to locate the mirex_extract binary")
      return
    }

    let fileManager = NSFileManager.defaultManager()

    let mfUUID = NSUUID().UUIDString
    let arffUUID = NSUUID().UUIDString

    let tempMfURL = tempDirectory.URLByAppendingPathComponent("\(mfUUID).mf")
    let tempArffURL = tempDirectory.URLByAppendingPathComponent("\(arffUUID).arff")

    // Write a temporary .mf file containing the track's URL for Marsyas
    do {
      try wavURL.path!.writeToURL(tempMfURL, atomically: false, encoding: NSUTF8StringEncoding)
    } catch {
      print("Error writing filename to temporary .mf file")
      return
    }

    // Execute the mirex_extract command to analyze the track
    let task = NSTask()
    task.launchPath = mirexPath
    task.arguments = [tempMfURL.path!, tempArffURL.path!]
    task.launch()
    task.waitUntilExit()

    // Store the timbre data in the track object
    self.store64DimensionalTimbreVector(tempArffURL)

    // Clean up temporary files. Wav files are huge - we don't want them cluttering
    // up the user's disk until the app quits!
    do {
      try fileManager.removeItemAtURL(tempMfURL)
      try fileManager.removeItemAtURL(tempArffURL)
    } catch {
      print("Could not remove files at \(tempMfURL), \(tempArffURL): \(error)")
    }
  }

  func parseTempoOutput(pipe: NSPipe) -> Int {
    let data = NSString(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: NSASCIIStringEncoding) as! String

    if data.rangeOfString("MRS_WARNING") != nil {
        // Error computing tempo if MRS_WARNING is in the output
        return 0
    }

    let lines = data.componentsSeparatedByString("\n")
    let tempoLine = lines.filter { $0.hasPrefix("Estimated tempo") }.first
    let tempo = tempoLine?.componentsSeparatedByString(" ").last

    return Int(tempo!)!
  }

  func computeTempo(wavURL: NSURL) {
    guard let tempoPath = TrackEntity.tempoPath else {
      print("Unable to locate the tempo binary")
      return
    }

    // Execute the tempo command to analyze the track's BPM
    let task = NSTask()
    let pipe = NSPipe()
    task.launchPath = tempoPath
    task.arguments = [wavURL.path!]
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()

    var tempo = abs(self.parseTempoOutput(pipe))

    // Account (somewhat heavy-handedly) for octave errors.
    // Most electronic dance music's BPM ranges from about 80 to 180
    // (give or take 10 bpm) depending on the genre. In order to ensure the
    // BPM is (most likely) in the correct octave, arbitrarily set BPM limits
    // to within 70...190 bpm.
    if tempo != 0 {
      while tempo > 190 {
        tempo /= 2
      }
      while tempo < 70 {
        tempo *= 2
      }
    }

    self.tempo = tempo
  }

  func getOrCreateWavURL() -> (NSURL, Bool)? {
    var wavURL: NSURL

    let isWav = NSURL(fileURLWithPath: self.filename!).pathExtension == "wav"
    if !isWav {
      print("Converting \(self.relativeFilename!) to .wav")

      // Use ffmpeg to create a temporary wav copy of the track
      guard let ffmpegPath = TrackEntity.ffmpegPath else {
        print("Unable to locate the ffmpeg binary")
        return nil
      }

      let uuid = NSUUID().UUIDString
      wavURL = tempDirectory.URLByAppendingPathComponent("\(uuid).wav")

      let task = NSTask()
      task.launchPath = ffmpegPath
      task.arguments = ["-i", self.filename!, wavURL.path!]
      task.launch()
      task.waitUntilExit()
    } else {
      // Simply use the track's file path as the WAV URL
      wavURL = NSURL(fileURLWithPath: self.filename!)
    }

    // Invert the boolean to indicate whether or not we had to convert the file
    let converted = !isWav
    return (wavURL, converted)
  }

  func analyze() {
    self.analyzed = AnalysisState.inProgress.rawValue
    // Save the new analysis state to signal the UI
    if self.managedObjectContext != nil {
      self.dataController.save()
    }

    // Get (or create via conversion) the WAV URL for the track
    guard let (wavURL, converted) = self.getOrCreateWavURL() else {
      // There was some issue creating the Wav file - most likely the
      // FFMPEG binary couldn't be located
      return
    }

    // Compute timbre vector and (if necessary) tempo
    self.computeTimbre(wavURL)

    // Compute the tempo for tracks shorter than 20 minutes long.
    // The vast majority of electronic dance tracks clock in somewhere between
    // 5 and ~10 minutes long - allowing for up to 20 minutes gives a bit of
    // a buffer for this. Files longer than 20 minutes are more likely to be
    // non-track files (for example, DJ mixes or podcasts.)
    // The tempo executable is extremely slow on files of long lengths, so
    // forgo processing files that are likely not tracks anyway.
    if self.tempo! == 0 && Int(self.duration!) < 1200 {
      self.computeTempo(wavURL)
    }

    // Delete the WAV file if we converted from another format
    if converted {
      do {
        try NSFileManager.defaultManager().removeItemAtURL(wavURL)
      } catch {
        print("Could not remove file at \(wavURL): \(error)")
      }
    }

    self.analyzed = AnalysisState.complete.rawValue
    // Save the new analysis state to signal the UI
    if self.managedObjectContext != nil {
      self.dataController.save()
    }
  }
}

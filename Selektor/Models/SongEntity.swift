//
//  SongEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData
import Cocoa
import ObjectiveC
import QuartzCore

@objc(SongEntity)
class SongEntity: SelektorObject {

  // MARK: Properties
  @NSManaged dynamic var analyzed: NSNumber
  @NSManaged dynamic var dateAdded: NSDate?
  @NSManaged dynamic var duration: NSNumber?
  @NSManaged dynamic var filename: String?
  @NSManaged dynamic var loudness: NSNumber?
  @NSManaged dynamic var tempo: NSNumber?
  @NSManaged dynamic var album: String?
  @NSManaged dynamic var artist: String?
  @NSManaged dynamic var genre: String?
  @NSManaged dynamic var key: String?
  @NSManaged dynamic var label: String?
  @NSManaged dynamic var timbreVectors: NSSet?

  // MARK: Convenience properties
  dynamic var relativeFilename: String? {
    get { return NSURL(fileURLWithPath: self.filename!).lastPathComponent ?? nil }
  }

  dynamic var timbreVectorSet: NSMutableSet {
    get { return self.mutableSetValueForKey("timbreVectors") }
  }

  dynamic var mammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.MeanAccMeanMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.MeanAccMeanMem) }
  }

  dynamic var masmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.MeanAccStdMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.MeanAccStdMem) }
  }

  dynamic var sammTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.StdAccMeanMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.StdAccMeanMem) }
  }

  dynamic var sasmTimbre: TimbreVectorEntity? {
    get { return self.getTimbreForSummaryType(SummaryType.StdAccStdMem) }
    set { self.setTimbreForSummaryType(newValue!, summaryType: SummaryType.StdAccStdMem) }
  }

  // MARK: Convenience getter and setter functions for retrieving/storing timbre vectors
  // of a given summary type
  func getTimbreForSummaryType(summaryType: SummaryType) -> TimbreVectorEntity? {
    return timbreVectorSet.filter({
      ($0 as! TimbreVectorEntity).summaryType == summaryType.rawValue
    }).first as? TimbreVectorEntity
  }

  func setTimbreForSummaryType(newVector: TimbreVectorEntity, summaryType: SummaryType) {
    // Remove old timbre vector if necessary
    self.removeTimbreForSummaryType(summaryType)

    // Set the summary type for the new vector and add it to the timbres set
    newVector.summaryType = summaryType.rawValue
    timbreVectorSet.addObject(newVector)
  }

  func removeTimbreForSummaryType(summaryType: SummaryType) {
    if let oldVector = self.getTimbreForSummaryType(summaryType) {
      // Remove the old vector for the summary type
      timbreVectorSet.removeObject(oldVector)
    }
  }

  // MARK: Store
  func store64DimensionalTimbreVector(arffFileURL: NSURL) {
    do {
      let arffContents = try String(contentsOfURL: arffFileURL)
      let arffLines = arffContents.componentsSeparatedByString("\n")

      // Extract the vector from the ARFF file.
      // Since only one song was analyzed, only one vector will be contained
      // in the file, so we always know the position of the vector relative to
      // the end of the file.
      let vectorString = arffLines[arffLines.endIndex - 2]
      var stringFeatures = vectorString.componentsSeparatedByString(",")
      stringFeatures.removeLast(1) // Remove the file label
      let features = (stringFeatures.map({ Double($0)! }) as [Double]) // Cast strings to doubles

      // Split array into 16-dimensional vectors for each summary type
      let mammFeatures = Array(features[0...15])
      let masmFeatures = Array(features[16...31])
      let sammFeatures = Array(features[32...47])
      let sasmFeatures = Array(features[48...63])

      // Set up vectors
      self.mammTimbre = self.createTimbreVectorFromFeaturesArray(mammFeatures)
      self.masmTimbre = self.createTimbreVectorFromFeaturesArray(masmFeatures)
      self.sammTimbre = self.createTimbreVectorFromFeaturesArray(sammFeatures)
      self.sasmTimbre = self.createTimbreVectorFromFeaturesArray(sasmFeatures)

    } catch {
      print("Error reading from ARFF file at \(arffFileURL)")
    }
  }

  func createTimbreVectorFromFeaturesArray(features: [Double]) -> TimbreVectorEntity {
    let dc = delegate.dc
    let vector: TimbreVectorEntity = dc.createEntity()

    vector.centroid = features[0]
    vector.rolloff = features[1]
    vector.flux = features[2]
    vector.mfcc = Array(features[3...11])

    return vector
  }

  override class func getEntityName() -> String {
    return "Song"
  }

  override func awakeFromInsert() {
    super.awakeFromInsert()

    // Set default values for NSManaged properties
    dateAdded = NSDate()
  }
}
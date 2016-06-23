//
//  GenreEntity.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation
import CoreData

@objc(GenreEntity)
class GenreEntity: SelektorObject {

  // MARK: Properties
  @NSManaged var name: String?
  @NSManaged var songs: NSSet?

  override class func getEntityName() -> String {
    return "Genre"
  }

  class func createOrFetchGenre(name: String, dc: DataController, inout genresDict: [String: GenreEntity]) -> GenreEntity {
    guard let genre = genresDict[name] else {
      let genre: GenreEntity = dc.createEntity()
      genre.name = name
      genresDict[name] = genre
      return genre
    }
    return genre
  }
}

//
//  SelektorObject.swift
//  Selektor
//
//  Created by James Gray on 2016-05-28.
//  Copyright © 2016 James Gray. All rights reserved.

import Foundation
import CoreData

// Subclass of NSManagedObject that entity classes should subclass for the purpose
// of exposing their entity names to the DataController via the `getEntityName` method.
// NOTE: This could also be accomplished with an NSManagedObject extension, however
// I've opted to simply subclass NSManagedObject in case I need other common
// functionality that only makes sense within the context of this app.
class SelektorObject: NSManagedObject {

  // XXX: Hack due to Swift's lack of support for class vars as of yet.
  // A `class func` is effectively equivalent to a `static func`, but can be
  // overridden by subclasses (unlike static funcs.)
  // Similarly, `static var`s cannot be overridden (and `class vars` don't exist)
  // so we must use a getter method instead.
  class func getEntityName() -> String {
    print("Subclasses should override abstract method `getEntityName`!")
    abort()
  }
}
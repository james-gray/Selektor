//
//  CountTransformer.swift
//  Selektor
//
//  Created by James Gray on 2016-06-22.
//  Copyright © 2016 James Gray. All rights reserved.
//

import Foundation

class CountTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    let plural = num == 1 ? "" : "s"
    return "\(num) item\(plural) total"
  }
}

class FilenameTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    return value?.lastPathComponent
  }
}

class DurationTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    let minutes = num / 60
    let seconds = String(format: "%02d", num % 60)
    return "\(minutes):\(seconds)"
  }
}

class AnalysisStateTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    guard let num = value as? Int else {
      return ""
    }

    switch num {
    case AnalysisState.inProgress.rawValue:
      return "\u{1F550}" // 🕐
    case AnalysisState.complete.rawValue:
      return "\u{2714}" // ✔️
    default:
      return ""
    }
  }
}

class SelectionTransformer: NSValueTransformer {
  override func transformedValue(value: AnyObject?) -> AnyObject? {
    // XXX: Return false to prevent hiding for any selected tracks, since for some
    // reason the name of certain tracks is causing the "Select Next Track" button
    // to be hidden
    return false
  }
}

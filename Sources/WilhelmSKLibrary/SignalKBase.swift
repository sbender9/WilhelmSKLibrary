//
//  File.swift
//  WilhelmSKLibrary
//
//  Created by Scott Bender on 9/26/24.
//

import Foundation

@available(iOS 17, *)
open class SignalKBase: NSObject, SignalKServer {
  
  private var values: [String: SKValue] = [:]
  private var sources: [String: [String:SKValue]] = [:]
  
  open func getObservableSelfPath(_ path: String, source: String? = nil) -> SKValue {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func getSelfPath(_ path: String, source: String? = nil) async throws -> SKValue {
    return SKValue(SKPathInfo("dummy"))
  }

  open func get(_ path: String, source: String?) -> SKValue? {
    if let source {
      var sourceMap = sources[source]
      if sourceMap == nil {
        sourceMap = [:]
        sources[source] = sourceMap
      }
      return sourceMap![path]
    } else {
      return values[path]
    }
  }
  
  open func getQuck(_ path: String, source: String?) -> SKValue? {
    if let source {
      if var sourceMap = sources[source] {
        return sourceMap[path]
      }
    }
    return values[path]
  }

  
  func getValues() -> [String: SKValue]
  {
    return values
  }
  
  open func getOrCreateValue(_ path: String, source: String?) -> SKValue {
    if let value = get(path, source: source) {
      return value
    } else {
      let value = SKValue(SKPathInfo(path))
      if let source {
        sources[source]![path] = value
      } else {
        values[path] = value
      }
      return value
    }
  }
}

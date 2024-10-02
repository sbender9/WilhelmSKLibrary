//
//  File.swift
//  WilhelmSKLibrary
//
//  Created by Scott Bender on 9/26/24.
//

import Foundation

@available(iOS 17, *)
open class SignalKBase: NSObject, SignalKServer, @unchecked Sendable {
  private var values : [String: SKValueBase] = [:]
  private var sources: [String: [String:SKValueBase]] = [:]
  
  private var anyValues: [String: SKValue<Any>] = [:]
  private var anySources: [String: [String:SKValue<Any>]] = [:]

  
  open func getObservableSelfPath<T>(_ path: String, source: String? = nil) -> SKValue<T> {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func getSelfPath<T>(_ path: String, source: String? = nil) async throws -> SKValue<T> {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func putSelfPath(path: String, value: Any?, completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void ) {
  }
  
  open func getSelfPath<T>(_ path: String, source: String?, completion: @escaping (Bool, SKValueBase, Error?) -> Void) -> SKValue<T> {
    let res : SKValue<T> = SKValue(SKPathInfo("dummy"))
    completion(true, res, nil)
    return res
  }
  
  open func putSelfPath(path: String, value: Any?) async throws -> [String:Any] {
    return [:]
  }
  
  public func setValue(_ base:SKValueBase, value: Any?)
  {
    if let skvalue = base as? SKValue<SKBool> {
      skvalue.value = SKBool(value)
    } else if let skvalue = base as? SKValue<Double> {
      skvalue.value = value as? Double
    } else if let skvalue = base as? SKValue<String> {
      skvalue.value = value as? String
    } else if let skvalue = base as? SKValue<Int> {
      skvalue.value = value as? Int
    } else if let skvalue = base as? SKValue<Float> {
      skvalue.value = value as? Float
    } else if let skvalue = base as? SKValue<Any> {
      /*
      if let val = value as? Bool {
        skvalue.value = SKBool(val)
      } else { */
        skvalue.value = value
      //}
    } else if let skvalue = base as? SKValue<Array<String>> {
      skvalue.value = value as? Array<String>
    } else {
      print("invalid value \(String(describing: value))")
    }
  }

  open func clearCache(_ path: String, source:String? = nil)
  {
    if source != nil {
      if let val = self.sources[source!]?[path] {
        val.updated = nil
      }
      if let val = self.anySources[source!]?[path] {
        val.updated = nil
      }
    } else {
      if let val = self.values[path] {
        val.updated = nil
      }
      if let val = self.anyValues[path] {
        val.updated = nil
      }
    }
  }
  
  open func getTyped(_ path: String, source: String?) -> SKValueBase? {
    if let source {
      let sourceMap = sources[source]
      if sourceMap == nil {
        return nil
      }
      return sourceMap![path]
    } else {
      return values[path]
    }
  }
  
  open func getAny(_ path: String, source: String?) -> SKValue<Any>? {
    if let source {
      let sourceMap = anySources[source]
      if sourceMap == nil {
        return nil
      }
      return sourceMap![path]
    } else {
      return anyValues[path]
    }
  }

  open func get<T>(_ path: String, source: String?) -> SKValue<T>? {
    if T.self == Any.self {
      if let source {
        var sourceMap = anySources[source]
        if sourceMap == nil {
          sourceMap = [:]
          anySources[source] = sourceMap
        }
        return sourceMap![path] as? SKValue<T>
      } else {
        return anyValues[path] as? SKValue<T>
      }
    } else {
      if let source {
        var sourceMap = sources[source]
        if sourceMap == nil {
          sourceMap = [:]
          sources[source] = sourceMap
        }
        return sourceMap![path] as? SKValue<T>
      } else {
        return values[path] as? SKValue<T>
      }
    }
  }
  
  /*
  open func getQuck<T>(_ path: String, source: String?) -> SKValue<T>? {
    if T.Type.self == Any.self {
      if let source {
        if let sourceMap = anySources[source] {
          return sourceMap[path] as! SKValue<T>
        }
      }
      return values[path] as! SKValue<T>

    } else {
      if let source {
        if let sourceMap = sources[source] {
          return sourceMap[path] as! SKValue<T>
        }
      }
      return values[path] as! SKValue<T>
    }
  }
   */
  
  func getValues() -> [String : SKValueBase]
  {
    return values
  }
  
  func getAnyValues() -> [String: SKValue<Any>]
  {
    return anyValues
  }

  
  open func getOrCreateValue<T>(_ path: String, source: String? ) -> SKValue<T> {
    if let value : SKValue<T> = get(path, source: source) {
      return value
      /*
      if let value = value as? SKValue<T> {
        return value
      } else {
        //FIXME: type does not match??
        return SKValue<T>(SKPathInfo(path))
      }
       */
    } else {
      let value : SKValue<T> = SKValue<T>(SKPathInfo(path))
      if T.self == Any.self {
        if let source {
          anySources[source]![path] = value as? SKValue<Any>
        } else {
          anyValues[path] = value as? SKValue<Any>
        }
      } else {
        if let source {
          sources[source]![path] = value
        } else {
          values[path] = value
        }
      }
      return value
    }
  }
}

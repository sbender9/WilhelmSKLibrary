//
//  File.swift
//  WilhelmSKLibrary
//
//  Created by Scott Bender on 9/26/24.
//

import Foundation

@available(iOS 17, *)
open class SignalKBase: NSObject, SignalKServer {
  var connectionName: String?
  let cache = ValueCache()

  public override init()
  {
  }
  
  public init(connectionName: String)
  {
    self.connectionName = connectionName
  }
  
  open func getSelfPath<T>(_ path: String, source: String?, delegate: SessionDelegate) -> SKValue<T> {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func getObservableSelfPath<T>(_ path: String, source: String? = nil) -> SKValue<T> {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func getSelfPath<T>(_ path: String, source: String? = nil) async throws -> SKValue<T> {
    return SKValue(SKPathInfo("dummy"))
  }
  
  open func getSelfPaths(_ paths: [PathRequest], delegate: SessionDelegate) -> [String:SKValueBase]
  {
    return ["dummy": SKValueBase(SKPathInfo("dummy"))]
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
      debug("invalid value \(String(describing: value))")
    }
  }
  
  func createValue(_ ofType: String, path: String) -> SKValueBase?
  {
    let info = SKPathInfo(path)
    switch ofType {
    case "SKBool": return SKValue<SKBool>(info)
    case "Double": return SKValue<Double>(info)
    case "String": return SKValue<String>(info)
    case "Int": return SKValue<Int>(info)
    case "Float": return SKValue<Float>(info)
    case "Any": return SKValue<Any>(info)
    case "Array<String>": return SKValue<Array<String>>(info)
    default:
      debug("could not create value of type \(ofType)")
      return nil
    }
  }
  
  open func clearCache(_ path: String, source:String? = nil)
  {
    cache.clear(path, source: source)
  }
    
  open func getOrCreateValue<T>(_ path: String, source: String? ) -> SKValue<T> {
    return cache.get(path, source: source, create: true)!
  }
  
  open func setSKValue(_ value: Any?, path: String, source: String?, timestamp: String?, meta: [String: Any]?) {
    cache.set(value, path: path, source: source, timestamp: timestamp, meta: meta)
  }
  
  open func getUniqueCachedValues() -> [String:SKValueBase] {
    return cache.getUniqueCachedValues()
  }
}

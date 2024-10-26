//
//  File.swift
//  WilhelmSKLibrary
//
//  Created by Scott Bender on 10/4/24.
//

import Foundation


@available(iOS 17, *)
class ValueCache {
  var caches : [String: Any] = [:]
  let lock = NSLock()
  
  init() {
    caches["SKBool"] = ValueTypeCache<SKBool>()
    caches["Int"] = ValueTypeCache<Int>()
    caches["Float"] = ValueTypeCache<Float>()
    caches["Double"] = ValueTypeCache<Double>()
    caches["String"] = ValueTypeCache<String>()
    caches["Any"] = ValueTypeCache<Any>()
    caches["Array<String>"] = ValueTypeCache<Array<String>>()
    caches["Dictionary<String, Double>"] = ValueTypeCache<[String:Double]>()
  }
  
  func get<T>(_ path: String, source: String? = nil, create: Bool = false) -> SKValue<T>? {
    let type = String(describing: T.self)
    var cache = caches[type] as? ValueTypeCache<T>
    if cache == nil {
      debug("ValueCache mising cache for \(type)")
      return nil
    }
    return cache!.get(path, source: source, create: create)
  }
  
  func get(_ path: String, source: String?, type: String) -> SKValueBase? {
    let cache = caches[type]
    switch type {
      case "SKBool":
        return (cache as! ValueTypeCache<SKBool>).get(path, source: source)
      case "Int":
        return (cache as! ValueTypeCache<Int>).get(path, source: source)
      case "Float":
        return (cache as! ValueTypeCache<Float>).get(path, source: source)
      case "Double":
        return (cache as! ValueTypeCache<Double>).get(path, source: source)
      case "String":
        return (cache as! ValueTypeCache<String>).get(path, source: source)
      case "Any":
        return (cache as! ValueTypeCache<Any>).get(path, source: source)
      case "Array<String>":
        return (cache as! ValueTypeCache<Array<String>>).get(path, source: source)
      case "Dictionary<String, Double>":
        return (cache as! ValueTypeCache<[String:Double]>).get(path, source: source)
      default:
        debug("ValueCache no cache for \(type)")
        return nil
    }
  }
    
  func put(_ value: SKValueBase, path: String, source: String?, type: String) {
    var cache = caches[type]
    switch type {
    case "SKBool":
      (cache as! ValueTypeCache<SKBool>).put(value, path: path, source: source)
    case "Int":
      (cache as! ValueTypeCache<Int>).put(value, path: path, source: source)
    case "Float":
      (cache as! ValueTypeCache<Float>).put(value, path: path, source: source)
    case "Double":
      (cache as! ValueTypeCache<Double>).put(value, path: path, source: source)
    case "String":
      (cache as! ValueTypeCache<String>).put(value, path: path, source: source)
    case "Any":
      (cache as! ValueTypeCache<Any>).put(value, path: path, source: source)
    case "Array<String>":
      (cache as! ValueTypeCache<Array<String>>).put(value, path: path, source: source)
      case "Dictionary<String, Double>":
        (cache as! ValueTypeCache<[String:Double]>).put(value, path: path, source: source)
    default:
      return
    }
  }
  
  func set(_ value: Any?, path: String, source: String?, timestamp: String?, meta: [String: Any]?) {
    for cache in caches.values {
      if let cache = cache as? ValueTypeCache<SKBool> {
        cache.set(value, path: path, source: source, timestamp: timestamp, meta:meta)
      } else if let cache = cache as? ValueTypeCache<Double> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<String> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<Int> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<Float> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<Any> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<Array<String>> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else if let cache = cache as? ValueTypeCache<[String:Double]> {
        cache.set(value, path: path, source: source, timestamp: timestamp,meta:meta)
      } else {
        debug("missing cache \(String(describing: cache))")
      }
    }
  }
  
  func clear(_ path: String, source: String?) {
    for cache in caches.values {
      if let cache = cache as? ValueTypeCache<SKBool> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<Double> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<String> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<Int> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<Float> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<Any> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<Array<String>> {
        cache.clear(path, source: source)
      } else if let cache = cache as? ValueTypeCache<[String:Double]> {
        cache.clear(path, source: source)
      } else {
        debug("missing cache \(String(describing: cache))")
      }
    }
  }
  
  func getUniqueCachedValues() -> [String:SKValueBase] {
    var res : [String:SKValueBase] = [:]
    for cache in caches.values {
      if let cache = cache as? ValueTypeCache<SKBool> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<Double> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<String> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<Int> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<Float> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<Any> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<Array<String>> {
        cache.getPaths(&res)
      } else if let cache = cache as? ValueTypeCache<[String:Double]> {
        cache.getPaths(&res)
      } else {
        debug("missing cache \(String(describing: cache))")
      }
    }
    return res
  }

}

@available(iOS 17, *)
class ValueTypeCache<T> {
  
  var cache : [String:SKValue<T>] = [:]
  var sources : [String:[String:SKValue<T>]] = [:]
  let lock = NSLock()
  
  func get(_ path: String, source: String? = nil, create: Bool = false) -> SKValue<T>? {
    lock.lock()
    //debug("ValueTypeCache<\(T.self)> get for \(path) create: \(create)")
    if let source = source {
      var sourceMap = sources[source, default: [:]]
      var value = sourceMap[path]
      guard create == true || value != nil else { lock.unlock(); return nil }
      value = SKValue<T>(SKPathInfo(path))
      sourceMap[path] = value
      lock.unlock()
      return value
    } else {
      var value = cache[path]
      guard create == true && value == nil else { lock.unlock(); return value }
      value = SKValue<T>(SKPathInfo(path))
      cache[path] = value
      lock.unlock()
      return value
    }
  }
  
  func get(_ path: String, source: String? = nil) -> SKValueBase? {
    lock.lock()
    //debug("ValueTypeCache<\(T.self)> get for \(path)")
    if let source = source {
      var sourceMap = sources[source, default: [:]]
      lock.unlock()
      return sourceMap[path]
    } else {
      lock.unlock()
      return cache[path]
    }
  }
  
  func put(_ value: SKValueBase, path: String, source: String?) {
    lock.lock()
    if let source = source {
      if let skvalue = self.sources[source]?[path] { //FIXME, implement
        //debug("ValueTypeCache<\(T.self)> put \(value) for \(path)")
        //skvalue.value = val as? T
        //skvalue.setTimestamp(timestamp)
        //skvalue.info.updateMeta(meta)
      } else {
        debug("ValueTypeCache<\(T.self)> attempt to put a \(value)")
      }
    } else {
      if let value = value as? SKValue<T> { //FIXME: error??
        //debug("ValueTypeCache<\(T.self)> put \(value) for \(path)")
        self.cache[path] = value
      } else {
        debug("ValueTypeCache<\(T.self)> attempt to put a \(value)")
      }
    }
    lock.unlock()
  }
  
  //@MainActor
  func set(_ value: Any?, path: String, source: String?, timestamp: String?, meta: [String: Any]?) {
    //let value = T.self == SKBool.self && value as? SKBool == nil ? SKBool(value) : value
    lock.lock()
    var val = value
    if T.self == SKBool.self { //FIXME: make sure this is comething that can be a bool -> string, Bool, number, ignore everything else
      if value as? SKBool == nil {
        val = SKBool(val)
      }
    }
    if let source = source {
      if let skvalue = self.sources[source]?[path] {
        //debug("ValueTypeCache<\(T.self)> setting \(value) \(source) for \(path)")
        skvalue.value = val as? T
        skvalue.setTimestamp(timestamp)
        skvalue.info.updateMeta(meta)
      }
    } else {
      if let skvalue = self.cache[path] {
        //debug("ValueTypeCache<\(T.self)> setting \(value) for \(path)")
        skvalue.value = val as? T
        skvalue.setTimestamp(timestamp)
        skvalue.info.updateMeta(meta)
      }
    }
    lock.unlock()
  }
  
  func clear(_ path: String, source: String? = nil)
  {
    lock.lock()
    debug("ValueTypeCache<\(T.self)> clear \(path)")
    if let source = source {
      if let sourceMap = sources[source],
         let value = sourceMap[path] {
        value.cached = nil
      }
    } else {
      for sourceMap in sources.values {
        sourceMap[path]?.cached = nil
      }
    }
    cache[path]?.cached = nil
    lock.unlock()
  }
  
  func getPaths(_ paths: inout [String:SKValueBase]) {
    lock.lock()
    //debug("ValueTypeCache<\(T.self)> get paths")
    for value in cache.values {
      if paths[value.info.path] == nil {
        paths[value.info.path] = value
      }
    }

    for sourceMap in sources.values {
      for value in sourceMap.values {
        if paths[value.info.path] == nil {
          paths[value.info.path] = value
        }
      }
    }
    lock.unlock()
  }
}

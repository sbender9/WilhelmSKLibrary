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
  
  func get<T>(_ path: String, source: String? = nil, create: Bool = false) -> SKValue<T>? {
    lock.withLock {
      let type = String(describing: T.self)
      var cache = caches[type] as? ValueTypeCache<T>
      if cache == nil && create == false {
        return nil
      }
      if cache == nil {
        cache = ValueTypeCache<T>()
        caches[type] = cache
      }
      return cache!.get(path, source: source, create: create)
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
    lock.withLock {
      if let source = source {
        var sourceMap = sources[source, default: [:]]
        var value = sourceMap[path]
        guard create == true || value != nil else { return nil }
        value = SKValue<T>(SKPathInfo(path))
        sourceMap[path] = value
        return value
      } else {
        var value = cache[path]
        guard create == true && value == nil else { return value }
        value = SKValue<T>(SKPathInfo(path))
        cache[path] = value
        return value
      }
    }
  }
  
  func set(_ value: Any?, path: String, source: String?, timestamp: String?, meta: [String: Any]?) {
    lock.withLock {
      //let value = T.self == SKBool.self && value as? SKBool == nil ? SKBool(value) : value
      var val = value
      if T.self == SKBool.self {
        if value as? SKBool == nil {
          val = SKBool(val)
        }
      }
      if let source = source {
        if let skvalue = sources[source]?[path] {
          skvalue.value = val as? T
          skvalue.setTimestamp(timestamp)
          skvalue.info.updateMeta(meta)
        }
      } else {
        if let skvalue = cache[path] {
          skvalue.value = val as? T
          skvalue.setTimestamp(timestamp)
          skvalue.info.updateMeta(meta)
        }
      }
    }
  }
  
  func clear(_ path: String, source: String? = nil)
  {
    lock.withLock {
      if let source = source {
        if var sourceMap = sources[source],
           let value = sourceMap[path] {
          value.updated = nil
        }
      } else {
        for var sourceMap in sources.values {
          sourceMap[path]?.updated = nil
        }
      }
      cache[path]?.updated = nil
    }
  }
  
  func getPaths(_ paths: inout [String:SKValueBase]) {
    for sourceMap in sources.values {
      for value in sourceMap.values {
        paths[value.info.path, default: { value }()]
      }
    }
  }
}

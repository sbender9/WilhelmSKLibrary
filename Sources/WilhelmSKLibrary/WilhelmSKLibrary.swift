import Foundation

//nonisolated(unsafe)
private var unitPreferences : [UnitTypes:Dimension]?


@available(iOS 17, *)
//@MainActor
var signalK: SignalKServer?

@available(iOS 17, *)
//@MainActor
public func getSignalK() -> SignalKServer {
  return signalK!
}

@available(iOS 17, *)
//@MainActor
public func setSignalK(_ sk : SignalKServer )
{
  signalK = sk
}

public func setUnitPreferences(_ preferences: [UnitTypes:Dimension])
{
  unitPreferences = preferences
}

public func getUnitPreferences() -> [UnitTypes:Dimension]?
{
  return unitPreferences
}

@available(iOS 17, *)
public func castAnyValue<T>(_ from: SKValue<Any>) -> SKValue<T> {
  let res = SKValue<T>(from.info)
  res.value = from.value as? T
  return res
}

public protocol JSONObject : Sendable {
  var value: Sendable { get }
}

public struct JSONArray : JSONObject {
  public var value: Sendable { get { array } }
  public var array : [JSONObject]
  
  public init(_ array: [JSONObject]) {
    self.array = array
  }
}

public struct JSONString : JSONObject {
  public var value: Sendable { get { string } }
  public var string : String
  
  public init(_ string: String) {
    self.string = string
  }
}

public struct JSONDictionary : JSONObject {
  public var value: Sendable { get { dictionary } }
  public var dictionary : [String:JSONObject]
  
  public init(_ dictionary: [String:JSONObject]) {
    self.dictionary = dictionary
  }
}

public func JSONObjectToAny(_ object: JSONObject) -> Any? {
  if let object = object as? JSONString {
    return object.string
  } else if let array = object as? JSONArray {
    return array.array.compactMap {
      return JSONObjectToAny($0)
    }
  } else if let object = object as? JSONDictionary {
    var dict : [String:Any] = [:]
    for (key, entry) in object.dictionary {
      if let obj = JSONObjectToAny(entry) {
        dict[key] = obj
      }
    }
    return dict
  } else {
    return nil
  }
}

public func getJSONObject(from json: Any?) -> JSONObject? {
  if let string = json as? String {
    return JSONString(string)
  } else if let array = json as? [Any] {
    return JSONArray(array.compactMap {
      return getJSONObject(from: $0)
    })
  } else if let dictionary = json as? [String:Any] {
    var dict : [String:JSONObject] = [:]
    for (key, entry) in dictionary {
      if let obj = getJSONObject(from: entry) {
        dict[key] = obj
      }
    }
    return JSONDictionary(dict)
  } else {
    return nil
  }
}


@available(iOS 14, *)
private let logger = Logger(OSLog.debug)

public func debug(_ message:String)
{
//#if DEBUG
    if #available (iOS 14, *) {
      logger.log("WilhelmSKD.network: \(message)")
      //print("WilhelmSKD.network: \(message)")
  } else {
    print("WilhelmSKD.network: \(message)")
  }
//#endif
}

import os.log

private var subsystem = Bundle.main.bundleIdentifier!

extension OSLog {
  
  /// Logs the view cycles like viewDidLoad.
  static let debug = OSLog(subsystem: subsystem, category: "views")
}



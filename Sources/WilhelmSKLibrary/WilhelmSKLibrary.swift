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


@available(iOS 14, *)
private let logger = Logger(OSLog.debug)

public func debug(_ message:String)
{
//#if DEBUG
    if #available (iOS 14, *) {
      //logger.log("WilhelmSKD.network: \(message)")
      print("WilhelmSKD.network: \(message)")
  } else {
    print("WilhelmSKD.network: \(message)")
  }
//#endif
}

import os.log

extension OSLog {
  private static var subsystem = Bundle.main.bundleIdentifier!
  
  /// Logs the view cycles like viewDidLoad.
  static let debug = OSLog(subsystem: subsystem, category: "network")
}



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

@available(iOS 14, *)
private let logger = Logger(OSLog.debug)

public func debug(_ message:String)
{
  var subsystem = Bundle.main.bundleIdentifier!
  
  if #available (iOS 14, *) {
    logger.log("WilhelmSKLib.debug: \(message)")
  } else {
    print("WilhelmSKLib.debug: \(message)")
  }
}

import os.log

extension OSLog {
  private static var subsystem = Bundle.main.bundleIdentifier!
  
  /// Logs the view cycles like viewDidLoad.
  static let debug = OSLog(subsystem: subsystem, category: "debug")
}

import Foundation

nonisolated(unsafe) private var unitPreferences : [UnitTypes:Dimension]?


@available(iOS 17, *)
@MainActor var signalK: SignalKServer?

@available(iOS 17, *)
@MainActor
public func getSignalK() -> SignalKServer {
  return signalK!
}

@available(iOS 17, *)
@MainActor
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

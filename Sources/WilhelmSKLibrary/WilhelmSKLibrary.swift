// The Swift Programming Language
// https://docs.swift.org/swift-book

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


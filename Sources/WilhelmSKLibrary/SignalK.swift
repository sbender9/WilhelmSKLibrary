//
//  File.swift
//  WilhelmSKLibrary
//
//  Created by Scott Bender on 9/23/24.
//

import Foundation
import AppIntents

private let defaultsSuiteName = "group.com.scottbender.wilhelm"
private let cacheTimeout : TimeInterval = -30

@available(iOS 17, *)
public protocol SignalKServer : AnyObject
{
  func getObservableSelfPath(_ path: String) -> SKPath
  func getSelfPath(_ path: String) async throws -> SKPath
}

/*
public class SignalKBase : SignalK
{
  public func getObservableSelfPath(_ path: String) -> SKPath
  {
  }
  
  public func getSelfPath(_ path: String) async throws -> SKPath
  {
  }
}
*/

public class SKPathInfo: ObservableObject, @unchecked Sendable {
  let id: String
  public let path: String
  @Published public private(set) var meta: [String: Any]?
  @Published public var displayName: String?
  //@Published public private(set) var units: String?
  public private(set) var units: Dimension?
  
  public init(_ path: String, meta: [String : Any]?) {
    self.id = path
    self.path = path
    self.meta = meta
    if let units = meta?["units"] as? String {
      self.units = skToSwiftUnits[units]
    }
    
    /*
    for key in skToSwiftUnits.keys {
      let formatter = MeasurementFormatter()
      formatter.unitStyle = .long
      let meas = Measurement(value: 10, unit: skToSwiftUnits[key]!)
      let unit = formatter.string(from: meas.unit)
      print("\(key) -> \(unit)")
    }*/
    
    self.displayName = meta?["displayName"] as? String
  }
  
  public func updateMeta(_ meta: [String: Any]?) {
    self.meta = meta
    if let units = meta?["units"] as? String {
      self.units = skToSwiftUnits[units]
    }
    self.displayName = meta?["displayName"] as? String
  }
}

@available(iOS 17, *)
public class SKPath: ObservableObject, @unchecked Sendable
{
  @Published public var info: SKPathInfo
  @Published public var value: Any?
  
  public init(_ info: SKPathInfo) {
    self.info = info
  }
  
  public func getMeasurement(_ type: UnitTypes? = nil) -> Measurement<Dimension>? {
    guard let value = value else { return nil }
    guard let number = value as? Double else { return nil }
    if let units = info.units {
      var measurement = Measurement(value: number, unit: units)
      
      if let conversion = preferedUnits(type) {
        measurement = measurement.converted(to: conversion)
      }
      
      return measurement
    } else {
      return nil
    }
  }
  
  public func preferedUnits(_ type:UnitTypes? = nil) -> Dimension? {
    var theType = type
    
    if theType == nil {
      if let units = self.info.units {
        theType = defaultUnitConversion[units.symbol]
      }
    }
    
    if let theType {
      return defaultUnits[theType]
    }
    
    if let units = self.info.units {
      return defaultNonPrefUnitConversion[units.symbol]
    }
    
    return nil
  }
  
  public func doubleValue() -> Double? {
    return value as? Double
  }
  
  public func intValue() -> Int? {
    return value as? Int
  }
  
  public func boolValue() -> Bool? {
    return value as? Bool  == true || value as? Int == 1 || value as? String == "on"
  }
  
  public func stringValue() -> String? {
    return value as? String
  }
}


/*
let unitTypesMap : [String:String] = [
  "m": kShortDistance,
  "m/s": kSpeed,
  "Pa": kEnginePressure,
  "rad": kAngle,
  "K": kTemperature,
  "m3": kVolume,
  "ratio": kRatio
]

let unitsNames : [String:String] = [
  kKilometers: "Kilometers",
  kMeters: "Meters",
  kFeet: "Feet",
  kKnots: "Knots",
  kCelcius: "Celsius",
  kFahrenheit: "Fahrenheit",
  kKelvin: "Kelvin",
  kLiters: "Liters",
  kGallons: "Gallons",
  kDegrees: "Degrees",
  kPercent: "%",
  kVolts: "Volts",
  kAmps: "Amps",
  kWatts: "Watts"
]*/

public enum UnitTypes: String {
  case longDistance = "units.Long Distance"
  case shortDistance = "units.Short Distance"
  case windSpeed = "units.Wind Speed"
  case speed = "units.Speed"
  case depth = "units.Depth"
  case volume = "units.Volume"
  case temperature = "units.Temperature"
  case enginePressure = "units.Engine Pressure"
  case environmentalPressure = "units.Atmospheric Pressure"
  case position = "units.Position"
  case rateOfTurn = "units.Rate Of Turn"
  case flowRate = "units.Flow Rate"
  case fuelEconomy = "units.Fuel Economy"
  case energy = "units.Energy"
}


//FIXME: add location/position, rate of turn, flow rate convrters
nonisolated(unsafe) let defaultUnits : [UnitTypes:Dimension] = [
  .longDistance: UnitLength.miles,
  .shortDistance: UnitLength.feet,
  .windSpeed: UnitSpeed.knots,
  .speed: UnitSpeed.knots,
  .depth: UnitLength.feet,
  .volume: UnitVolume.gallons,
  .temperature: UnitTemperature.fahrenheit,
  .enginePressure: UnitPressure.poundsForcePerSquareInch, //FIXME should be kPSI
  .environmentalPressure: UnitPressure.inchesOfMercury,
  .energy: UnitEnergy.kilowattHours,
  //.rateOfTurn: KDegreesM,
  //.flowRate: kGallonsH,
  //.fuelEconomy: kFuelEconomy,
]

nonisolated(unsafe) let skToSwiftUnits :[String:Dimension] = [
  UnitAngle.radians.symbol: UnitAngle.radians,
  UnitDuration.seconds.symbol: UnitDuration.seconds,
  UnitElectricCharge.coulombs.symbol: UnitElectricCharge.coulombs,
  UnitElectricCurrent.amperes.symbol: UnitElectricCurrent.amperes,
  UnitElectricPotentialDifference.volts.symbol: UnitElectricPotentialDifference.volts,
  UnitEnergy.joules.symbol: UnitEnergy.joules,
  UnitFrequency.hertz.symbol: UnitFrequency.hertz,
  UnitLength.meters.symbol: UnitLength.meters,
  UnitPower.watts.symbol: UnitPower.watts,
  //UnitPressure.pascals FIXME
  UnitSpeed.metersPerSecond.symbol: UnitSpeed.metersPerSecond,
  UnitTemperature.kelvin.symbol: UnitTemperature.kelvin,
  "m3": UnitVolume.cubicMeters,
  RatioUnit.ratio.symbol: RatioUnit.ratio
]

nonisolated(unsafe) let defaultNonPrefUnitConversion :[String:Dimension] = [
  UnitAngle.radians.symbol: UnitAngle.degrees,
  UnitElectricCharge.coulombs.symbol: UnitElectricCharge.ampereHours,
  UnitElectricCurrent.amperes.symbol: UnitElectricCurrent.amperes,
  UnitEnergy.joules.symbol: UnitEnergy.kilowattHours,
]

nonisolated(unsafe) let defaultUnitConversion :[String:UnitTypes] = [
  UnitTemperature.kelvin.symbol: .temperature,
  "m3": .volume,
  UnitSpeed.metersPerSecond.symbol: .speed,
  UnitLength.meters.symbol: .shortDistance,
]

final class RatioUnit: Dimension {
  nonisolated(unsafe) static let ratio = RatioUnit(symbol: "ratio", converter: UnitConverterLinear(coefficient: 1.0))
  nonisolated(unsafe) static let percent = RatioUnit(symbol: "%", converter: UnitConverterLinear(coefficient: 100))
  
  override class func baseUnit() -> RatioUnit {
    return percent
  }}

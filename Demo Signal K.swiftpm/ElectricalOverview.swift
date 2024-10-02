//
//  ElectricalOverviewWidget.swift
//  Wilhelm
//
//  Created by Scott Bender on 9/25/24.
//  Copyright © 2024 Scott Bender. All rights reserved.
//

import SwiftUI
import WidgetKit
import WilhelmSKLibrary
import WilhelmSKDummyGauges

@available(iOS 17, *)
struct ElectricalOverviewView: View {
    //@Environment(\.theme) var theme: Theme
    //@Environment(\.config) var config: GaugeConfig?
    //@Environment(\.boat) var boat: SignalKBase?
    
     let boat: SignalKBase?
     let config: ElectricalOverviewGauge?
     let theme: Theme?
    
    @ObservedObject var systemState : SKValue<String>
    @ObservedObject var dcLoads: SKValue<Double>
    @ObservedObject var stateOfCharge: SKValue<Double>
    @ObservedObject var chargerCurrent: SKValue<Double>
    @ObservedObject var current: SKValue<Double>
    @ObservedObject var power: SKValue<Double>
    @ObservedObject var voltage: SKValue<Double>
    @ObservedObject var temperature: SKValue<Double>
    @ObservedObject var timeRemaining: SKValue<Double>
    @ObservedObject var solarPower: SKValue<Double>
    @ObservedObject var solarVoltage: SKValue<Double>
    @ObservedObject var solarCurrent: SKValue<Double>
    @ObservedObject var solarMode: SKValue<String>
    @ObservedObject var acPower: SKValue<Double>
    @ObservedObject var acGridPower: SKValue<Double>
    @ObservedObject var acGridVoltage: SKValue<Double>
    @ObservedObject var acGridCurrent: SKValue<Double>
    @ObservedObject var acCurrent: SKValue<Double>
    
    init(_ boat: SignalKBase, config: ElectricalOverviewGauge, theme:Theme) {
        self.boat = boat
        self.config = config
        self.theme = theme
        
        _systemState = Self.getValue(boat: boat, config: config, key: "systemState")
        _dcLoads = Self.getValue(boat: boat, config: config, key: "dcLoadsOverride")
        _stateOfCharge = Self.getValue(boat: boat, config: config, key: "stateOfChargeOverride")
        _chargerCurrent = Self.getValue(boat: boat, config: config, key: "chargerCurrentOverride")
        _current = Self.getValue(boat: boat, config: config, key: "currentOverride")
        _power = Self.getValue(boat: boat, config: config, key: "powerOverride")
        _voltage = Self.getValue(boat: boat, config: config, key: "voltageOverride")
        _temperature = Self.getValue(boat: boat, config: config, key: "temperatureOverride")
        _timeRemaining = Self.getValue(boat: boat, config: config, key: "timeRemainingOverride")
        _solarPower = Self.getValue(boat: boat, config: config, key: "solarPowerOverride")
        _solarVoltage = Self.getValue(boat: boat, config: config, key: "solarVoltageOverride")
        _solarCurrent = Self.getValue(boat: boat, config: config, key: "solarCurrentOverride")
        _solarMode = Self.getValue(boat: boat, config: config, key: "solarModeOverride")
        _acPower = Self.getValue(boat: boat, config: config, key: "acPowerOverride")
        _acGridPower = Self.getValue(boat: boat, config: config, key: "acGridPowerOverride")
        _acGridVoltage = Self.getValue(boat: boat, config: config, key: "acGridVoltageOverride")
        _acGridCurrent = Self.getValue(boat: boat, config: config, key: "acGridCurrentOverride")
        _acCurrent = Self.getValue(boat: boat, config: config, key: "acCurrentOverride")
    }
    
#if IN_WILHELMSK
    init(_ boat: SignalKBase,
         config: ElectricalOverviewGauge,
         completion: @escaping (Bool, SKValueBase, Error?) -> () = { (result, value, error) -> Void in}  )
    {
        _systemState = Self.getWidgetValue(boat, config: config, key: "systemState", completion:completion)
        _dcLoads = Self.getWidgetValue(boat, config: config, key: "dcLoadsOverride", completion:completion)
        _stateOfCharge = Self.getWidgetValue(boat, config: config, key: "stateOfChargeOverride", completion:completion)
        _chargerCurrent = Self.getWidgetValue(boat, config: config, key: "chargerCurrentOverride", completion:completion)
        _current = Self.getWidgetValue(boat, config: config, key: "currentOverride", completion:completion)
        _power = Self.getWidgetValue(boat, config: config, key: "powerOverride", completion:completion)
        _voltage = Self.getWidgetValue(boat, config: config, key: "voltageOverride", completion:completion)
        _temperature = Self.getWidgetValue(boat, config: config, key: "temperatureOverride", completion:completion)
        _timeRemaining = Self.getWidgetValue(boat, config: config, key: "timeRemainingOverride", completion:completion)
        _solarPower = Self.getWidgetValue(boat, config: config, key: "solarPowerOverride", completion:completion)
        _solarVoltage = Self.getWidgetValue(boat, config: config, key: "solarVoltageOverride", completion:completion)
        _solarCurrent = Self.getWidgetValue(boat, config: config, key: "solarCurrentOverride", completion:completion)
        _solarMode = Self.getWidgetValue(boat, config: config, key: "solarModeOverride", completion:completion)
        _acPower = Self.getWidgetValue(boat, config: config, key: "acPowerOverride", completion:completion)
        _acGridPower = Self.getWidgetValue(boat, config: config, key: "acGridPowerOverride", completion:completion)
        _acGridVoltage = Self.getWidgetValue(boat, config: config, key: "acGridVoltageOverride", completion:completion)
        _acGridCurrent = Self.getWidgetValue(boat, config: config, key: "acGridCurrentOverride", completion:completion)
        _acCurrent = Self.getWidgetValue(boat, config: config, key: "acCurrentOverride", completion:completion)
    }
    
    static func getWidgetValue<T>(_ boat: SignalKBase,
                                  config: ElectricalOverviewGauge,
                                  key: String,
                                  completion: @escaping (Bool, SKValueBase, Error?) -> Void = { (result, value, error) -> () in} ) -> ObservedObject<SKValue<T>>
    {
        guard let path = config.getPath(key)
        else {
            return ObservedObject(wrappedValue:SKValue(SKPathInfo(key)))
        }
        
        //let value :SKValue<T> = boat.getSelfPath(path, source:config.getSource(key), completion:{ (result, error) -> () in})
        //let value :SKValue<T> = boat.getSelfPath(path, source:config.getSource(key), completion:completion)
        
        return config.getSelfPath(boat, path: path, source:config.getSource(key), completion:completion)
    }
#endif
    
    static func getValue<T>(boat: SignalKBase?, config: ElectricalOverviewGauge, key: String) -> ObservedObject<SKValue<T>>
    {
        guard let path = config.getPath(key)
        else {
            return ObservedObject(wrappedValue:SKValue(SKPathInfo(key)))
        }
        return config.getObservableSelfPath(boat!, path: path, source: config.getSource(key))
    }
    
    var body: some View {
        GeometryReader { g in
            VStack {
                HStack() {
                    let showGrid = config!.customizations["showGrid"] as? Bool
                    if showGrid == nil || showGrid! {
                        GenericOverviewGauge(topLeading: "Grid",
                                             topTrailing: getMeasurementText(acGridVoltage),
                                             bottomLeading: getMeasurementText(acGridCurrent, decs:1),
                                             bottomLeading2: nil,
                                             bottom: nil,
                                             bottomTrailing: getMeasurementText(acGridPower),
                                             bottomTrailing2: nil,
                                             center: nil)
                        //.frame(width: (g.size.width * 0.45))//, height:g.size.height * 0.20)
                        //.padding(5)
                    }
                    GenericOverviewGauge(topLeading: "Inverter/Charger",
                                         topTrailing: getMeasurementText(chargerCurrent, decs:1),
                                         bottomLeading: getMeasurementText(systemState),
                                         bottomLeading2: nil,
                                         bottom: nil,
                                         bottomTrailing: nil, //getMeasurementText(chargerCurrent), FIXME!
                                         bottomTrailing2: nil,
                                         center: nil)
                    //.frame(width: (g.size.width * 0.45))//, height:g.size.height * 0.20)
                    //.padding(5)
                    GenericOverviewGauge(topLeading: "AC Loads",
                                         topTrailing: nil,
                                         bottomLeading: getMeasurementText(acCurrent, decs:1),
                                         bottomLeading2: nil,
                                         bottom: nil,
                                         bottomTrailing: getMeasurementText(acPower),
                                         bottomTrailing2: nil,
                                         center: nil)
                    //.frame(width: g.size.width * 0.45)//, height:g.size.height * 0.20)
                    //.padding(5)
                }
                HStack() {
                    GenericOverviewGauge(topLeading: "Battery",
                                         topTrailing: getMeasurementText(temperature),
                                         bottomLeading: getMeasurementText(voltage, decs:1),
                                         bottomLeading2: getDischarging(power: power),
                                         bottom: getMeasurementText(current, decs:1),
                                         bottomTrailing: getMeasurementText(power),
                                         bottomTrailing2: getTimeRemaining(timeRemaining),
                                         center: getMeasurementText(stateOfCharge))
                    
                    
                    //.padding([.leading, .trailing])
                    //.frame(width: g.size.width)//, height:g.size.height * 0.60)
                }
                .frame(height: g.size.height * 0.50)
                HStack() {
                    let showDCLoads = config!.customizations["showDCLoads"] as? Bool
                    if showDCLoads == nil || showDCLoads! {
                        GenericOverviewGauge(topLeading: "DC Loads",
                                             topTrailing: nil,
                                             bottomLeading: getDCAmps(voltage: voltage, dcLoads: dcLoads),
                                             bottomLeading2: nil,
                                             bottom: nil,
                                             bottomTrailing: getMeasurementText(dcLoads, decs:1),
                                             bottomTrailing2: nil,
                                             center: nil)
                        //.frame(width: (g.size.width * 0.45))//, height:g.size.height * 0.20)
                        //.padding(5)
                    }
                    let showSolar = config!.customizations["showSolar"] as? Bool
                    if showSolar == nil || showSolar! {
                        GenericOverviewGauge(topLeading: "Solar",
                                             topTrailing: getMeasurementText(solarMode),
                                             bottomLeading: getMeasurementText(solarCurrent, decs:1),
                                             bottomLeading2: nil,
                                             bottom: getMeasurementText(solarVoltage),
                                             bottomTrailing: getMeasurementText(solarPower),
                                             bottomTrailing2: nil,
                                             center: nil)
                        //.frame(width: g.size.width * 0.45)//, height:g.size.height * 0.20)
                        //.padding(5)
                    }
                }
            }
        }
    }
}

@available(iOS 17, *)
public func getDCAmps(voltage: SKValue<Double>, dcLoads: SKValue<Double> ) -> String {
    guard let voltage = voltage.value as? Double,
          let loads = dcLoads.value as? Double
    else { return "--" }
    
    return String(format: "%.1f A", loads / voltage)
}

@available(iOS 17, *)
public func getDischarging(power: SKValue<Double> ) -> String {
    guard let value = power.value as? Double
    else { return "--" }
    
    return value > 20 ? "Charging" : (value < -20 ? "Discharging" : "Idle")
}

@available(iOS 17, *)
public func getTimeRemaining(_ timeRemaining: SKValue<Double> ) -> String {
    guard let remaining = timeRemaining.value as? Double
    else { return "--:--" }
    
    let hours = Int(remaining) / 3600
    let remainder = Int(remaining) - hours * 3600
    let mins = remainder / 60;
    
    return "\(hours):\(mins)"
}

@available(iOS 17, *)
public func getMeasurementText(_ value: SKValue<Double>, decs: Int = 0) -> String
{
    
    let measurement = value.getMeasurement()
    if let val = measurement?.value ?? value.value as? Double {
        var units = measurement?.unit.symbol ?? value.info.meta?["units"] as? String
        if units != nil {
            if units == "%" {
                units = "%%"
            }
            return String(format: "%.*f \(units!)", decs, val)
        } else {
            return String(format: "%.*f", decs, val)
        }
    } else {
        return "--"
    }
}

@available(iOS 17, *)
public func getMeasurementText(_ value: SKValue<String>) -> String
{
    
    let measurement = value.getMeasurement()
    if let val = value.value as? String {
        return val.capitalized
    } else {
        return "--"
    }
}


let textPadding = 5.0

@available(iOS 17, *)
public struct GenericOverviewGauge: View {
    let topLeading: String?
    let topTrailing: String?
    let bottomLeading: String?
    let bottomLeading2: String?
    let bottom: String?
    let bottomTrailing: String?
    let bottomTrailing2: String?
    let center: String?
    
    public var body: some View {
        ZStack {
            BatteryBox()
                .overlay(alignment:.topLeading)
            {
                if let value = topLeading {
                    Text(value)
                        .egoText()
                    //.font(.system(size: 1000))
                    //.minimumScaleFactor(0.005)
                        .lineLimit(1)
                    //.fitToWidth()
                        .padding([.top, .leading], textPadding)
                }
            }
            .overlay(alignment:.topTrailing)
            {
                if let value = topTrailing {
                    Text(value)
                        .egoText()
                        .padding([.top, .trailing], textPadding)
                }
            }
            .overlay(alignment:.bottomLeading)
            {
                VStack(alignment: .leading) {
                    if let value = bottomLeading2 {
                        Text(value)
                            .egoText()
                    }
                    if let value = bottomLeading {
                        Text(value)
                            .egoText()
                    }
                }
                .padding([.bottom, .leading], textPadding)
            }
            .overlay(alignment:.bottom)
            {
                if let value = bottom {
                    Text(value)
                        .egoText()
                        .padding(.bottom, textPadding)
                }
            }
            .overlay(alignment:.bottomTrailing)
            {
                VStack(alignment: .trailing) {
                    if let value = bottomTrailing2 {
                        Text(value)
                            .egoText()
                    }
                    if let value = bottomTrailing {
                        Text(value)
                            .egoText()
                    }
                }
                .padding([.bottom, .trailing], textPadding)
            }
            if let value = center {
                Text(value)
                    .fitToWidth()
                    .foregroundStyle(.white)
                    .padding(30)
                //.font(.title)
            }
        }
    }
}

@available(iOS 17, *)
private struct BatteryBox: View {
    var body: some View {
        Rectangle()
        //.fill(Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255))
            .fill(
                LinearGradient(gradient: Gradient(colors: [Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255), Color.black]),
                               startPoint: .top,
                               endPoint: UnitPoint(x: 0.5, y: 1.5))
                /*
                 LinearGradient(stops: [
                 Gradient.Stop(color: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255), location: 0.45),
                 Gradient.Stop(color: .black, location: 0.55),
                 ], startPoint: .top, endPoint: .bottom)
                 */
            )
        
        
            .cornerRadius(7.5)
        //.border(.white)
    }
}

@available(iOS 17, *)
struct EGOTitleModifier: ViewModifier {
    //@Environment(\.widgetFamily) var family
    //@Environment(\.widgetRenderingMode) var renderingMode
    
    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .foregroundStyle(.white)
    }
}

@available(iOS 17, *)
private extension Text {
    func egoText() -> some View  {
        self.modifier(EGOTitleModifier())
    }
}

@available(iOS 17, *)
 #Preview {
     ElectricalOverviewView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: ElectricalOverviewGauge(electricalGaugeConfig), theme: Theme.theDefault())
 }

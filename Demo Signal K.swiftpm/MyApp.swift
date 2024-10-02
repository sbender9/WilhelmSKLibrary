import SwiftUI
import WilhelmSKLibrary
import WilhelmSKDummyGauges

let myUnitPrefs : [UnitTypes:Dimension] = [
    .longDistance: UnitLength.nauticalMiles,
    .shortDistance: UnitLength.feet,
    .windSpeed: UnitSpeed.knots,
    .speed: UnitSpeed.knots,
    .depth: UnitLength.inches,
    .volume: UnitVolume.gallons,
    .temperature: UnitTemperature.fahrenheit,
    .enginePressure: UnitPressure.poundsForcePerSquareInch,
    .environmentalPressure: UnitPressure.inchesOfMercury,
    .energy: UnitEnergy.kilowattHours,
]

let electricalGaugeConfig = [
    "acCurrentOverride": "electrical.inverters.257.acout.current",
    "acGridCurrentOverride": "electrical.inverters.257.acin.current",
    "acGridPowerOverride": "electrical.inverters.257.acin.power",
    "acGridVoltageOverride": "electrical.inverters.257.acin.voltage",
    "acPowerOverride": "electrical.inverters.257.acout.power",
    "chargerCurrentOverride": "electrical.chargers.257.current",
    "currentOverride": "electrical.batteries.houseBattery.current",
    "dcLoadsOverride": "electrical.venus.dcPower",
    "powerOverride": "electrical.batteries.houseBattery.power",
    "solarCurrentOverride": "electrical.solar.258.current",
    "solarModeOverride": "electrical.solar.258.controllerMode",
    "solarPowerOverride": "electrical.solar.258.panelPower",
    "solarVoltageOverride": "electrical.solar.258.panelVoltage",
    "stateOfChargeOverride": "electrical.batteries.houseBattery.capacity.stateOfCharge",
    "systemState": "electrical.venus.state",
    "temperatureOverride": "electrical.batteries.houseBattery.temperature",
    "timeRemainingOverride": "electrical.batteries.houseBattery.capacity.timeRemaining",
    "voltageOverride": "electrical.batteries.houseBattery.voltage",
]


//let host = "https://demo.signalk.org"
let host = "http://localhost:3000"

let gaugeConfig = GaugeConfig(["signalKPath": "environment.wind.speedApparent", "title": "Wind Speed"])

@main
struct MyApp: App {
    init() {
        WilhelmSKLibrary.setUnitPreferences(myUnitPrefs)
        WilhelmSKLibrary.setSignalK(WilhelmSKLibrary.RESTSignalK(host:host, updateRate: 3.0))
    }

    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: gaugeConfig, theme: Theme.theDefault())
                //ElectricalOverviewView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: ElectricalOverviewGauge(electricalGaugeConfig), theme: Theme.theDefault())
            }
        }
    }
}

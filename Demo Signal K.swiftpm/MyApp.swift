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

let host = "https://demo.signalk.org"

let gaugeConfig = GaugeConfig(["signalKPath": "environment.wind.speedApparent", "title": "Wind Speed"])

@main
struct MyApp: App {
    init() {
        WilhelmSKLibrary.setUnitPreferences(myUnitPrefs)
        WilhelmSKLibrary.setSignalK(WilhelmSKLibrary.RESTSignalK(host:host, updateRate: 3.0))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: gaugeConfig, theme: Theme.theDefault())
        }
    }
}

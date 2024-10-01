//
//  ContentView.swift
//  ExampleApp
//
//  Created by Scott Bender on 9/28/24.
//

import SwiftUI
import WilhelmSKLibrary
import WilhelmSKDummyGauges

struct ContentView: View {
  let config: GaugeConfig
  
  @ObservedObject var speed : SKValue<Double>
  let gradient = Gradient(colors: [.green, .yellow, .red])
  
  init(_ boat: SignalKBase, config: GaugeConfig, theme: Theme) {
    self.config = config
    
    _speed = config.getObservableSelfPath(boat, path: config.signalKPath, source:nil)
  }

  var body: some View {
    let measurement = speed.getMeasurement(.windSpeed)
    let val = measurement?.value ?? speed.value ?? 0
    
    VStack {
      Text(speed.info.displayName ?? config.title)
      
      Gauge(value:val, in: 0...40) {
        if let units = measurement?.unit.symbol {
          Text(units)
        }
      } currentValueLabel: {
        if let val = measurement?.value {
          Text(String(format: "%.*f", 0, val))
            .foregroundColor(.green)
        } else {
          Text("--")
        }
      }
      .gaugeStyle(.accessoryCircular)
      .animation(.interactiveSpring (response: 1,
                                     dampingFraction: 1, blendDuration: 1), value:val)
    }
    .tint(gradient)
    .scaleEffect(4)
  }
}

#Preview {
  ContentView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: gaugeConfig, theme: Theme.theDefault())
}

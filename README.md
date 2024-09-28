# WilhelmSKLibrary

A Swift Package that can be used to create iOS and Mac application on a mac using Xcode or an iPad using Swift Playgrounds. Very early in development, but I will add more features if there is any interest.

It was originally designed to allow users create custom WilhelmSK gauges using Swift, but can also be used to quickly and easily create Signal K iOS and Mac apps 

It currently only uses periodic REST calls to get data, I can add WebSocket streaming if there is any demand,

You also need to add a package dependency to https://github.com/sbender9/WilhelmSKDummyGauges

Swift PLayground and an iOS/Mac example included above



The example SwiftUI View 

```
struct ContentView: View {
  let config: GaugeConfig
  
  @ObservedObject var speed : SKValue
  let gradient = Gradient(colors: [.green, .yellow, .red])
  
  init(_ boat: SignalKBase, config: GaugeConfig, theme: Theme) {
    self.config = config
    
    _speed = config.getObservableSelfPath(boat, path: config.signalKPath, source:nil)
  }

  var body: some View {
    let measurement = speed.getMeasurement(.windSpeed)
    let val = measurement?.value ?? speed.doubleValue() ?? 0
    
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
```

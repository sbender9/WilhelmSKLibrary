//
//  StereoView.swift
//  Wilhelm
//
//  Created by Scott Bender on 9/28/24.
//  Copyright © 2024 Scott Bender. All rights reserved.
//

import SwiftUI
import WidgetKit
import WilhelmSKLibrary
import AppIntents
#if !IN_WILHELMSK
import WilhelmSKDummyGauges
#endif

private let device: String = "entertainment.device.fusion1"

@available(iOS 17, *)
struct StereoView: View {
  @Environment(\.inWidget) var inWidget
  @Environment(\.widgetFamily) var family
  @Environment(\.theme) var theme: Theme
  @Environment(\.config) var config: GaugeConfig?
  @Environment(\.boat) var boat: SignalKBase?
#if IN_WILHELMSK
  @Environment(\.connection) var connection: Connection?
#endif
  
  @ObservedObject var trackName : SKValue<Any>
  @ObservedObject var albumName : SKValue<String>
  @ObservedObject var artistName : SKValue<String>
  @ObservedObject var elapsedTime : SKValue<Double>
  @ObservedObject var length : SKValue<Double>
  @ObservedObject var number : SKValue<Int>
  @ObservedObject var totalTracks : SKValue<Int>
  @ObservedObject var playbackState : SKValue<SKBool>
  @ObservedObject var state : SKValue<String>
  @ObservedObject var source : SKValue<String>
  @ObservedObject var muted : SKValue<SKBool>
  @ObservedObject var volume : SKValue<Double>
  @ObservedObject var sources : SKValue<Array<String>>
  @ObservedObject var outputAlarms : SKValue<SKBool>
  
  @State private var volumeState: Double = 12
  @State private var selectedSource: String?
  @State private var newSourceSelected: Bool = false
  @State private var isEditingVolume = false
  @State private var isSourcePresented: Bool = false
  @State private var showingAlert = false
  @State private var alertTitle :String?
  @State private var alertMessage : String?
  
  init(_ boat: SignalKBase, config: Fusion, inWidget: Bool, completion: @escaping (Bool, SKValueBase, Error?) -> Void) {
    _trackName = Self.getValue(boat, config: config, key: "track.name", inWidget:inWidget, completion:completion)
    _albumName = Self.getValue(boat, config: config, key: "track.albumName", inWidget:inWidget, completion:completion)
    _artistName = Self.getValue(boat, config: config, key: "track.artistName", inWidget:inWidget, completion:completion)
    _elapsedTime = Self.getValue(boat, config: config, key: "track.elapsedTime", inWidget:inWidget, completion:completion)
    _length = Self.getValue(boat, config: config, key: "track.length", inWidget:inWidget, completion:completion)
    _number = Self.getValue(boat, config: config, key: "track.number", inWidget:inWidget, completion:completion)
    _totalTracks = Self.getValue(boat, config: config, key: "track.totalTracks", inWidget:inWidget, completion:completion)
    _playbackState = Self.getValue(boat, config: config, key: "playbackState", inWidget:inWidget, completion:completion)
    _state = Self.getValue(boat, config: config, key: "state", inWidget:inWidget, completion:completion)
    _source = Self.getValue(boat, config: config, key: "source", inWidget:inWidget, completion:completion)
    _muted = Self.getValue(boat, config: config, key: "output.zone1.isMuted", inWidget:inWidget, completion:completion)
    _volume = Self.getValue(boat, config: config, key: "output.zone1.volume.master", inWidget:inWidget, completion:completion)
    _sources = Self.getValue(boat, config: config, key: "sources", inWidget:inWidget, completion:completion)
    _outputAlarms = Self.getValue(boat, config: config, key: "outputAlarms", inWidget:inWidget, completion:completion)
    selectedSource = source.value
  }
  
  static func getValue<T>(_ boat: SignalKBase, config: Fusion, key: String, inWidget: Bool, completion: @escaping (Bool, SKValueBase, Error?) -> Void) -> ObservedObject<SKValue<T>>
  {
    let path = "\(device).\(key)"
    
    if inWidget {
      return config.getSelfPath(boat, path:path, source: nil, completion: completion)
    } else {
      return config.getObservableSelfPath(boat, path: path)
    }
  }
  
  var body: some View {
    
    GeometryReader { g in
      VStack {
        
        ZStack {
          Box()
          VStack(spacing: 0.0) {
            if let name = trackName.value  {
              Text("\(name)")
                .fitToWidth()
              //.font(.headline)
                .foregroundStyle(.primary)
                .foregroundColor(.wSKtext(theme))
            }
            if let artist = artistName.value {
              Text("\(artist)")
              //font(.subheadline)
                .foregroundStyle(.secondary)
                .fitToWidth()
                .foregroundColor(.wSKtext(theme))
            }
            if let album = albumName.value {
              Text("\(album)")
              //.font(.caption)
                .foregroundStyle(.secondary)
                .fitToWidth()
                .foregroundColor(.wSKtext(theme))
            }
            if let num = number.value,
               let total = totalTracks.value
            {
              Text("\(num) Of \(total)")
              //.font(.caption)
                .foregroundStyle(.secondary)
                .fitToWidth()
                .foregroundColor(.wSKtext(theme))
            }
          }
          .padding([.top, .bottom], inWidget ? 25 : 60.0)
          .padding([.leading, .trailing], 8.0)
        }
        .overlay(alignment: .topLeading) {
          if inWidget {
#if IN_WILHELMSK
            Button(intent:StereoIntent(command: StereoCommand.toggleOutputAlarms, connection: connection)) {
              Image(systemName: "bell")
                .padding(8)
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
#endif
          }
          else {
            Button(action: {
              putPath("outputAlarms", value: outputAlarms.value?.boolValue == true ? false : true, errorTitle: "Power Error") { state in }
            }) {
              Image(systemName: outputAlarms.value?.boolValue == true ? "bell" : "bell.slash")
                .tint(.wSKtext(theme))
                .padding(8)
            }
            .modifier(StereoButtonStyle())
          }
        }
        .overlay(alignment: .topTrailing) {
          if inWidget {
#if IN_WILHELMSK
            Button(intent:StereoIntent(command: StereoCommand.togglePower, connection: connection)) {
              Image(systemName: "power")
                .padding(8)
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
#endif
          }
          else {
            Button(action: {
              putPath("state", value: state.value == "on" ? false : true, errorTitle: "Power Error") { state in }
            }) {
              Image(systemName: "power")
                .tint(.wSKtext(theme))
                .padding(8)
            }
            .modifier(StereoButtonStyle())
          }
        }
        .overlay(alignment: .bottom) {
          if inWidget == false {
            HStack {
              if let time = elapsedTime.value,
                 let len = length.value  {
                TimeText(time, includeHours: len > (60*60))
                  .font(.caption)
                //.foregroundStyle(.tertiary)
                  .foregroundColor(.wSKtext(theme))
              }
              if let time = elapsedTime.value,
                 let duration = length.value {
                Gauge(value:time, in: 0...duration) {
                } currentValueLabel: {
                }
                .tint(.wSKtext(theme))
                .animation(.smooth, value:time)
              }
              if let len = length.value {
                TimeText(len, includeHours: len > (60*60))
                  .font(.caption)
                //.foregroundStyle(.tertiary)
                  .foregroundColor(.wSKtext(theme))
              }
            }
            .padding(8)
          }
        }
        HStack {
          if inWidget {
#if IN_WILHELMSK
            Button(intent:StereoIntent(command: StereoCommand.toggleMute, connection: connection)) {
              Image(systemName: muted.value?.boolValue ?? false  ?  "speaker.slash" : "speaker")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
#endif
          }
          if !inWidget {
            Menu {
              Picker("Source", selection: $selectedSource) {
                if let sources = sources.value {
                  ForEach(0 ..< sources.count, id: \.self) { value in
                    Text(sources[value]).tag(sources[value])
                  }
                }
              }
              .onChange(of: selectedSource, { oldValue, newValue in
                newSourceSelected = true
                if let newValue {
                  putPath("output.zone1.source", value: newValue, errorTitle: "Error changing source") { state in
                    if state != .pending {
                      newSourceSelected = false
                    }
                  }
                }
              })
            } label: {
              Text(selectedSource ?? "Source")
                .foregroundStyle(.wSKtext(theme))
                .padding(5)
                .frame(width: g.size.width * 0.20)
                .background(
                  RoundedRectangle(cornerRadius: 5)
                    .stroke(.wSKtext(theme), lineWidth: 1)
                )
            }
          }
          if inWidget {
#if IN_WILHELMSK
            Button(intent:StereoIntent(command: StereoCommand.prev, connection: connection)) {
              Image(systemName: "arrowshape.left.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
            
            Button(intent:StereoIntent(command: StereoCommand.playPause, connection: connection)) {
              Image(systemName: "playpause.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
            
            Button(intent:StereoIntent(command: StereoCommand.next, connection: connection)) {
              Image(systemName: "arrowshape.right.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
#endif
          } else {
            Button(action: {
              putPath("prev", value: true, errorTitle: "Play Error") { state in }
            }) {
              Image(systemName: "arrowshape.left.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
            
            let playing = playbackState.value?.boolValue ?? false
            Button(action: {
              putPath(playing ? "pause" : "play", value: true, errorTitle: "Play Error") { state in }
            }) {
              Image(systemName: playing ? "pause.circle" : "play.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
            
            Button(action: {
              putPath("next", value: true, errorTitle: "Play Error") { state in }
            }) {
              Image(systemName: "arrowshape.right.circle")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
          }
          
          if !inWidget {
            Button(action: {}) {
              Text("Devices")
                .foregroundStyle(.wSKtext(theme))
                .padding(5)
                .frame(width: g.size.width * 0.20)
                .background(
                  RoundedRectangle(cornerRadius: 5)
                    .stroke(.wSKtext(theme), lineWidth: 1)
                )
            }
            .modifier(StereoButtonStyle())
            .frame(width: g.size.width * 0.20)
          }
        }
        //.fixedSize(horizontal: false, vertical:true)
        //.frame(maxWidth: .infinity)
        .frame(height: g.size.height * 0.1)
        HStack {
          if inWidget == false {
            Button(action: {
              putPath("output.zone1.isMuted", value: muted.value?.boolValue == true ? false : true, errorTitle: "Pause Error") { state in }
            }) {
              Image(systemName: muted.value?.boolValue  == true ?  "speaker.slash" : "speaker")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
            Slider(
              value: $volumeState,
              in: 0...24,
              step: 1,
              onEditingChanged: { editing in
                if editing == false {
                  putPath("output.zone1.volume.master", value: volumeState, errorTitle: "Error changing volume") { state in
                    if state != .pending {
                      isEditingVolume = false
                    }
                  }
                } else {
                  isEditingVolume = editing
                }
              }
            )
            .frame(width: g.size.width * 0.75)
            Button(action: {
            }) {
              Image(systemName: muted.value?.boolValue == true ?  "speaker.slash" : "hifispeaker.2")
                .resizable()
                .scaledToFit()
                .tint(.wSKtext(theme))
            }
            .modifier(StereoButtonStyle())
          }
        }
        .frame(height: g.size.height * 0.1)
        .onReceive(volume.$value) {
          if isEditingVolume == false {
            volumeState = $0  ?? 12
          }
        }
        .onReceive(source.$value) {
          if newSourceSelected == false {
            selectedSource = $0  ?? "Source"
          }
        }
      }
    }
    .alert(isPresented: $showingAlert) {
      Alert(title: Text(alertTitle!), message: Text(alertMessage!), dismissButton: .default(Text("OK")))
    }
  }
  func putPath(_ path: String, value: Any?, errorTitle: String, completion: @escaping (SignalKResponseState?) -> ()  ) {
    boat?.putSelfPath(path: "\(device).\(path)", value: value,
                      completion: { state, statusCode, res, error in
      if error != nil || (state == .failed || state == .completed && statusCode != 200) {
        alertTitle = errorTitle
        if let message = res?["message"] as? String {
          alertMessage = message
        } else if let error {
          alertMessage = error.localizedDescription
        } else if statusCode != nil {
          alertMessage = "Status code \(statusCode!)"
        } else {
          alertMessage = "Unknown Error"
        }
        completion(state)
        showingAlert = true
      } else if state == .pending {
        completion(state)
      } else if (state == .completed || state == .pending) && statusCode == 200 {
        completion(state)
      }
    })
    
  }
}

@available(iOS 17, *)
private struct Box: View {
  @Environment(\.theme) var theme: Theme
  
  var body: some View {
    RoundedRectangle(cornerRadius: 7.5)
      .fill(
        LinearGradient(gradient: Gradient(
          colors: [Color(theme.fusionDisplayViewColor), Color.wSKbackground(theme)]),
                       startPoint: .top,
                       endPoint: UnitPoint(x: 0.5, y: 1.5))
      )
    //.stroke(MyShapeStyle(), lineWidth:1)
      .stroke(.wSKtext(theme), lineWidth:1)
    //.cornerRadius(7.5)
    //.border(.white)
  }
}

@available(iOS 17, *)
struct StereoButtonStyle: ViewModifier {
  @Environment(\.inWidget) var inWidget
  
  func body(content: Content) -> some View {
    if inWidget {
      content.buttonStyle(.plain)
    } else {
      content.buttonStyle(.automatic)
    }
  }
}

#if IN_WILHELMSK
enum StereoCommand: String, Codable, Sendable {
  case play
  case playPause
  case next
  case prev
  case powerOn
  case powerOff
  case togglePower
  case mute
  case unMute
  case toggleMute
  case outputAlarmsOn
  case outputAlarmsOff
  case toggleOutputAlarms
}

@available(iOS 17, *)
extension StereoCommand: AppEnum {
  
  static let caseDisplayRepresentations: [StereoCommand : DisplayRepresentation] = [
    play: DisplayRepresentation(title: "Play"),
    playPause: DisplayRepresentation(title: "Play/Pause"),
    next: DisplayRepresentation(title: "Next Track"),
    prev: DisplayRepresentation(title: "Previous Track"),
    powerOn: DisplayRepresentation(title: "Power On"),
    powerOff: DisplayRepresentation(title: "Power Off"),
    togglePower: DisplayRepresentation(title: "Toggle Power"),
    mute: DisplayRepresentation(title: "Mute"),
    unMute: DisplayRepresentation(title: "UnMute"),
    toggleMute: DisplayRepresentation(title: "Toggle Mute"),
    outputAlarmsOn: DisplayRepresentation(title: "Output Alarms On"),
    outputAlarmsOff: DisplayRepresentation(title: "Output Alarms Off"),
    toggleOutputAlarms: DisplayRepresentation(title: "Toggle Output Alarms")
    
  ]
  
  
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(
      name: LocalizedStringResource("Stereo Command", table: "AppIntents"),
      numericFormat: LocalizedStringResource("Send stereo command \(placeholder: .int)", table: "AppIntents")
    )
  }
}


@available(iOS 17, *)
struct StereoIntent: AppIntent {
  static let title: LocalizedStringResource = "Stereo Commands"
  
  @Parameter(title: "Action")
  var command: StereoCommand?
  
  @Parameter(title: "Connection", query: ConnectionQuery())
  var connection: Connection?
  
  init() {}
  
  init(command: StereoCommand, connection: Connection?) {
    self.command = command
    self.connection = connection
  }
  
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let boat = try WidgetBoat.instance(connection)
    
    var dialog: IntentDialog
    
    if let command = command {
      var value : Any
      switch command {
      case .powerOn, .mute, .outputAlarmsOn:
        value = true
        
      case .powerOff, .unMute, .outputAlarmsOff:
        value = false
        
      default:
        value = true
      }
      
      _ = try await boat.putSelfPath(path:"\(device).\(command.rawValue)", value: value)
      
      dialog = IntentDialog("Ran stereo \(StereoCommand.caseDisplayRepresentations[command]!.title)")
    } else {
      dialog = IntentDialog("No command selected")
    }
    
    return .result(dialog: dialog)
  }
}
#endif

#if !IN_WILHELMSK
struct ContentView_Previews: PreviewProvider {
  static let theme = Theme.theDefault()
  static let config = Fusion([:])
  
  static var previews: some View {
    ZStack {
      Color.wSKbackground(theme)
      StereoView(WilhelmSKLibrary.getSignalK() as! SignalKBase, config: config, inWidget: false, completion:{ (result, value, error) -> () in} )
        .frame(height: 400)
    }
    .environment(\.theme, theme)
    .environment(\.inWidget, false)
    .environment(\.config, config)
    .environment(\.boat, WilhelmSKLibrary.getSignalK() as? SignalKBase)
  }
}
#endif


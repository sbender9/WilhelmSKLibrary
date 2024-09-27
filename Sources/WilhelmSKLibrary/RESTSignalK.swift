//
//  SignalK.swift
//  WilhelmSK
//
//  Created by Scott Bender on 9/22/24.
//  Copyright © 2024 Scott Bender. All rights reserved.
//

import Foundation
import Combine

@available(iOS 17, *)
open class RESTSignalK : SignalKBase, @unchecked Sendable {
  
  let restEndpoint: String
  let updateRate: Double
  
  //let session: URLSession
  var timer: Timer?
    
  public init(host: String, updateRate: Double = 0 )
  {
    //session = URLSession(configuration: .default)
    self.restEndpoint = "\(host)/signalk/v1/api/"
    self.updateRate = updateRate
  }
  
  public init(restEndpoint: String, updateRate: Double = 0 )
  {
    //session = URLSession(configuration: .default)
    self.restEndpoint = restEndpoint
    self.updateRate = updateRate
  }
  
  @MainActor
  func sendHttpRequest(urlString: String, method: String, body: Data?) async throws -> Any? {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let session = URLSession(configuration: .default)
    let (data, resp) = try await session.data(for: request)
    let status = (resp as! HTTPURLResponse).statusCode
    guard status == 200 else { throw SignalKError.message("invalid server response \(status)") }
    //print(status)
    //print(String(data: data, encoding: .utf8))
    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    return dict
  }
  
  @MainActor
  func sendGet(_ urlString: String) async throws -> Any?
  {
    return try await sendHttpRequest(urlString: urlString, method: "GET", body: nil)
  }
    
  @MainActor
  private func updatePath(_ value: SKValue) async throws {
    let path = value.info.path
    let urlString = "vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    
    do {
      //let theType = type(of: path)
      guard let info = try await sendGet(urlString) as? [String:Any] else { throw SignalKError.invalidServerResponse }
      guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
      
      let meta = info["meta"] as? [String: Any]
      value.info.updateMeta(meta)
      
      let values = info["values"] as? [String:[String:Any]]

      if value.source != nil {
        value.value = values?[source]?["value"]
        
        if let unSourced = get(path, source: nil) {
          unSourced.value = value.value
          unSourced.info.updateMeta(meta)
          unSourced.setTimestamp(values?[source]?["timestamp"] as? String)
        }
      } else {
        value.value = info["value"]
        value.source = source
        value.setTimestamp(info["timestamp"] as? String)
      }
      
      if values != nil {
        for (key, vmap) in values! {
          if let v = get(path, source: key) {
            v.value = vmap["value"]
            v.info.updateMeta(meta)
            v.setTimestamp(vmap["timestamp"] as? String)
          }
        }
      }
      
      startTimer()
      
    } catch {
      print(error)
    }
  }
  
  //@MainActor
  private func updatePaths() async {
    for path in getValues().values {
      do {
        try await updatePath(path)
      } catch {
        print(error)
      }
    }
  }
  
  private func startTimer() {
    if timer == nil && updateRate > 0 {
      timer = Timer.scheduledTimer(withTimeInterval: updateRate, repeats: true) { [self] timer in
        Task {
          await updatePaths()
        }
      }
    }
  }
  
  //@MainActor
  override public func getObservableSelfPath(_ path: String, source: String? = nil) -> SKValue
  {
    let value = getOrCreateValue(path, source: source)
    
    Task {
      do {
        try await updatePath(value)
      } catch {
        print(error)
      }
    }
    
    return value
  }
 
  //@MainActor
  override public func getSelfPath(_ path: String, source: String? = nil) async throws -> SKValue
  {
    let value = getOrCreateValue(path, source: source)
    
    try await updatePath(value)
    
    return value
  }
}

@available(iOS 16, *)
public enum SignalKError: Swift.Error, CustomLocalizedStringResourceConvertible {
  case invalidType
  case invalidServerResponse
  case message(_ message: String)
  
  @available(watchOS 9, *)
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case let .message(message): return "\(message)"
    case .invalidType: return "Invalid type"
    case .invalidServerResponse: return "Invalid error response"
    }
  }
}


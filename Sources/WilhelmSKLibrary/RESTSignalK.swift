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
open class RESTSignalK : NSObject, @unchecked Sendable, @preconcurrency SignalKServer
{
  //nonisolated(unsafe)
  //public static let shared = RESTSignalK()
  let restEndpoint: String
  let updateRate: Double
  
  let session: URLSession
  var timer: Timer?
    
  public init(host: String, updateRate: Double = 0 )
  {
    session = URLSession(configuration: .default)
    self.restEndpoint = "\(host)/signalk/v1/api/"
    self.updateRate = updateRate
  }
  
  public init(restEndpoint: String, updateRate: Double = 0 )
  {
    session = URLSession(configuration: .default)
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
  
  private var paths: [String: SKPath] = [:]
  
  public func get(_ path: String) -> SKPath? {
    return paths[path]
  }
  
  @MainActor
  private func updatePath(_ path: SKPath) async throws {
    let urlString = "vessels/self/\(path.info.path.replacingOccurrences(of: ".", with: "/"))"
    
    do {
      //let theType = type(of: path)
      guard let info = try await sendGet(urlString) as? [String:Any] else { throw SignalKError.invalidServerResponse }
      let res = info["value"]
      
      //let myPath = get(path.info.path)
      let meta = info["meta"] as? [String: Any]
      
      path.info.updateMeta(meta)
      
      path.value = res

      if let timestamp = info["timestamp"] as? String {
        do {
          path.timestamp = try Date(timestamp, strategy: Date.ISO8601FormatStyle.iso8601withFractionalSeconds)
        } catch {
          print(error)
        }
      }
      
      startTimer()
      
    } catch {
      print(error)
    }
  }
  
  //@MainActor
  private func updatePaths() async {
    for path in paths.values {
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
  public func getObservableSelfPath(_ path: String) -> SKPath
  {
    var skPath = paths[path]
    
    if skPath == nil {
      let pathInfo = SKPathInfo(path, meta: nil)
      skPath = SKPath(pathInfo)
      paths[path] = skPath
    }
    
    Task {
      do {
        try await updatePath(skPath!)
      } catch {
        print(error)
      }
    }
    
    return skPath!
  }
 
  //@MainActor
  public func getSelfPath(_ path: String) async throws -> SKPath
  {
    var skPath = paths[path]
    
    if skPath == nil {
      let pathInfo = SKPathInfo(path, meta: nil)
      skPath = SKPath(pathInfo)
      paths[path] = skPath
    }
    
    try await updatePath(skPath!)
    
    return skPath!
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

@available(iOS 16, *)
private extension ParseStrategy where Self == Date.ISO8601FormatStyle {
  static var iso8601withFractionalSeconds: Self { .init(includingFractionalSeconds: true) }
}

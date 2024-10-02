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
  public var cacheAge : TimeInterval = 1.0
  
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
    guard status != 401 else { throw SignalKError.unauthorized }
    guard status == 200 else { throw SignalKError.message("Invalid server response \(status)") }
    //print(status)
    //print(String(data: data, encoding: .utf8))
    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    return dict
  }
  
  @MainActor
  func sendHttpRequestIgnoringStatus(urlString: String, method: String, body: Data?) async throws -> Any? {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let session = URLSession(configuration: .default)
    let (data, _) = try await session.data(for: request)
    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    return dict
  }
  
  @MainActor
  func sendGet(_ urlString: String) async throws -> Any?
  {
    return try await sendHttpRequest(urlString: urlString, method: "GET", body: nil)
  }
  
  @MainActor
  func sendPut(_ urlString: String, data: Any) async throws -> Any? {
    guard JSONSerialization.isValidJSONObject(data) else { throw SignalKError.message("invalid put data") }
    let putData = try JSONSerialization.data(withJSONObject: data)
    return try await sendHttpRequestIgnoringStatus(urlString: urlString, method: "PUT", body: putData)
  }

        
  @MainActor
  private func updatePath(_ value: SKValueBase) async throws -> Bool {
    let path = value.info.path
    let urlString = "vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    
    if value.updated != nil && value.updated!.timeIntervalSinceNow > (cacheAge * -1) {
      return false
    }
    
    //make so another call does get made
    value.updated = Date()
    
    do {
      //let theType = type(of: path)
      guard let info = try await sendGet(urlString) as? [String:Any] else { throw SignalKError.invalidServerResponse }
      guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
            
      let meta = info["meta"] as? [String: Any]
      value.info.updateMeta(meta)
      
      let values = info["values"] as? [String:[String:Any]]

      if value.source != nil && values != nil {
        setValue(value, value:values?[source]?["value"])
        
        if let unSourced : SKValueBase = getTyped(path, source: nil) {
          setValue(unSourced, value:values?[source]?["value"])
          unSourced.info.updateMeta(meta)
          unSourced.setTimestamp(values?[source]?["timestamp"] as? String)
        }
        if let unSourced : SKValue<Any> = getAny(path, source: nil) {
          setValue(unSourced, value:values?[source]?["value"])
          unSourced.info.updateMeta(meta)
          unSourced.setTimestamp(values?[source]?["timestamp"] as? String)
        }
      } else {
        setValue(value, value: info["value"])
        value.source = source
        value.setTimestamp(info["timestamp"] as? String)
      }
      
      if values != nil {
        for (key, vmap) in values! {
          if let v : SKValueBase = getTyped(path, source: key) {
            setValue(v, value: vmap["value"])
            v.info.updateMeta(meta)
            v.setTimestamp(vmap["timestamp"] as? String)
          }
          if let v : SKValueBase = getAny(path, source: key) {
            setValue(v, value: vmap["value"])
            v.info.updateMeta(meta)
            v.setTimestamp(vmap["timestamp"] as? String)
          }
        }
      }
      
      startTimer()
      return true
    } catch {
      //print(error)
    }
    return false
  }
  
  //@MainActor
  private func updatePaths() async {
    //FIXME: go through souce maps also
    for path in getValues().values {
      do {
        let _ = try await updatePath(path)
      } catch {
        //print(error)
      }
    }
    for path in getAnyValues().values {
      do {
        let _ = try await updatePath(path)
      } catch {
        //print(error)
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
  override public func getObservableSelfPath<T>(_ path: String, source: String? = nil) -> SKValue<T>
  {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    Task {
      do {
        let _ = try await updatePath(value)
      } catch {
        print(error)
      }
    }
    
    return value
  }
 
  //@MainActor
  override public func getSelfPath<T>(_ path: String, source: String? = nil) async throws -> SKValue<T>
  {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    let _ = try await updatePath(value)
    
    return value
  }
  
  override public func getSelfPath<T>(_ path: String, source: String?, completion: @escaping (Bool, SKValueBase, Error?) -> Void) -> SKValue<T> {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    //Task {
    Task.detached { @MainActor in
      do {
        let updated = try await self.updatePath(value)
        completion(updated, value, nil)
      } catch {
        completion(false, value, error)
      }
    }
    
    return value
  }
  
  func processResponse(_ res: [String:Any], completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void) {
    guard let state = res["state"] as? String,
          let statusCode = res["statusCode"] as? Int,
          let requestId = res["requestId"] as? String
    else {
      completion(SignalKResponseState.failed, nil , res, SignalKError.invalidServerResponse)
      return
    }

    let skState = SignalKResponseState(rawValue: state) ?? SignalKResponseState.failed
    switch skState {
    case .completed:
      fallthrough
    case .failed:
      completion(skState, statusCode, res, nil)

    default:
      /*
      guard let href = res["href"] as? String else {
        completion(nil, nil , res, SignalKError.invalidServerResponse)
        return
      }
       */
      completion(skState, statusCode, res, nil)
      
      let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
        Task {
          do {
            let res = try await self.sendGet("/actions/\(requestId)")
            guard let res = res as? [String:Any]  else { throw SignalKError.invalidServerResponse }
            self.processResponse(res, completion: completion)
          } catch {
            completion(SignalKResponseState.failed, nil, nil, error)
          }
        }
      }
    }
  }
  
  override open func putSelfPath(path: String, value: Any?, completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void ) {
    let urlString = "vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    Task {
      do {
        let res = try await sendPut(urlString, data: ["value": value]) as! [String:Any]
        processResponse(res, completion: completion)
      } catch {
        completion(SignalKResponseState.failed, nil, nil, error)
      }
    }
  }
  
  override open func putSelfPath(path: String, value: Any?) async throws -> [String:Any] {
    let urlString = "vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    return try await sendPut(urlString, data: ["value": value]) as! [String:Any]
  }
}

@available(iOS 16, *)
public enum SignalKError: LocalizedError {
  case invalidType
  case invalidServerResponse
  case unauthorized
  case message(_ message: String)
  
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case let .message(message): return "\(message)"
    case .invalidType: return "Invalid type"
    case .invalidServerResponse: return "Invalid server response"
    case .unauthorized: return "Permission Denied"
    }
  }
  
  public var errorDescription: String? {
    switch self {
    case let .message(message): return "\(message)"
    case .invalidType: return "Invalid type"
    case .invalidServerResponse: return "Invalid server response"
    case .unauthorized: return "Permission Denied"
    }
  }
  
}

public enum SignalKResponseState: String {
  case completed = "COMPLETED"
  case failed = "FAILED"
  case pending = "PENDING"
}


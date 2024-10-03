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
open class RESTSignalK : SignalKBase {
  let restEndpoint: String
  let updateRate: Double
  public var cacheAge : TimeInterval = 1.0
  
  var timer: Timer?
    
  public init(host: String, updateRate: Double = 0 )
  {
    self.restEndpoint = "\(host)/signalk/v1/api/"
    self.updateRate = updateRate
    super.init()
  }
  
  public init(restEndpoint: String, connectionName:String, updateRate: Double = 0 )
  {
    self.restEndpoint = restEndpoint
    self.updateRate = updateRate
    super.init(connectionName: connectionName)
  }
  
  func sendBackgroundGetHttpRequest(urlString: String, forPath: String, sessionId: String, delegate: URLSessionDelegate)  {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let sessionData = SessionCache.shared.get(for: sessionId, delegate: delegate)

    debug("sending background request for \(url)")
    
    let task = sessionData.session.downloadTask(with:request)
    task.countOfBytesClientExpectsToSend = 0
    task.countOfBytesClientExpectsToReceive = 1024
    task.resume()
  }

  
  //@MainActor
  func sendHttpRequest(urlString: String, method: String, body: Data?) async throws -> Any? {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let session = URLSession(configuration: .default)
    let (data, resp) = try await session.data(for:request)
    let status = (resp as! HTTPURLResponse).statusCode
    guard status != 401 else { throw SignalKError.unauthorized }
    guard status == 200 else { throw SignalKError.message("Invalid server response \(status)") }
    //debug(status)
    //debug(String(data: data, encoding: .utf8))
    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    return dict
  }
  
  //@MainActor
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
  
  //@MainActor
  public func sendGet(_ urlString: String) async throws -> Any?
  {
    return try await sendHttpRequest(urlString: urlString, method: "GET", body: nil)
  }
  
  //@MainActor
  func sendPut(_ urlString: String, data: Any) async throws -> Any? {
    guard JSONSerialization.isValidJSONObject(data) else { throw SignalKError.message("invalid put data") }
    let putData = try JSONSerialization.data(withJSONObject: data)
    return try await sendHttpRequestIgnoringStatus(urlString: urlString, method: "PUT", body: putData)
  }

        
  //@MainActor
  private func updateVaue(_ value: SKValueBase) async throws -> Bool {
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
            
      setValueFromResponse(value, info: info, source: source)
      
      startTimer()
      return true
    } catch {
      debug("error update value \(error)")
    }
    return false
  }
  
  @MainActor
  func setValueFromDownloadResponse(path: String, source: String, type: String, data: Data) throws -> SKValueBase?
  {
    let source = source == "nil" ? nil : source
    
    var value : SKValueBase?
    if type == "Any" {
      value = getAny(path, source: source)
    } else {
      value = getTyped(path, source: source)
    }
    
    guard let value else { return nil } //it's gone! no worries
    
    guard let info = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
      throw SignalKError.invalidServerResponse
    }
    guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }

    setValueFromResponse(value, info: info, source: source)
    
    return value
  }
  
  func setValueFromResponse(_ value: SKValueBase, info: [String:Any], source: String )
  {
    let path = value.info.path
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
  }
  
  //@MainActor
  private func updatePaths() async {
    //FIXME: go through souce maps also
    for path in getValues().values {
      do {
        let _ = try await updateVaue(path)
      } catch {
        debug("error updatePath \(error)")
      }
    }
    for path in getAnyValues().values {
      do {
        let _ = try await updateVaue(path)
      } catch {
        debug("error any updatePath \(error)")
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
        let _ = try await updateVaue(value)
      } catch {
        debug("error getObservableSelfPath \(error)")
      }
    }
    
    return value
  }
 
  //@MainActor
  override public func getSelfPath<T>(_ path: String, source: String? = nil) async throws -> SKValue<T>
  {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    let _ = try await updateVaue(value)
    
    return value
  }
  
  override public func getSelfPath<T>(_ path: String, source: String?, delegate: SessionDelegate) -> SKValue<T> {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    let path = value.info.path
    let urlString = "vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    
    if value.updated != nil && value.updated!.timeIntervalSinceNow > (cacheAge * -1) {
      //FIME call delegate???
      //debug("getSelfPath using cache for \(path)")
      return value
    }
    
    //make so another call does get made
    value.updated = Date()

    let type : String  = String(describing: T.self)
    let sessionId = "\(self.connectionName!)/\(path)/\(source ?? "nil")/\(type)/\(delegate.kind)"
    
    sendBackgroundGetHttpRequest(urlString: urlString, forPath: path, sessionId: sessionId, delegate: delegate)
    
    return value
  }

  
  override public func getSelfPath<T>(_ path: String, source: String?, completion: @escaping (Bool, SKValueBase, Error?) -> Void) -> SKValue<T> {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    //Task {
    Task.detached { @MainActor in
      do {
        let updated = try await self.updateVaue(value)
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

public struct SessionData {
  public var session : URLSession
}

private let defaultsSuiteName = "group.com.scottbender.wilhelm"
private let pendingKey = "pendingSessions"

private func parseSessionId(_ id: String) -> (connection: String, path: String, source: String?, type: String, kind: String)?
{
  let parts = id.components(separatedBy: "/")
  guard parts.count == 5 else {
    debug("invalid session id '\(id)'")
    return nil
  }
  
  return (connection: parts[0],
          path: parts[1],
          source: parts[2] == "nil" ? nil : parts[2],
          type: parts[3],
          kind: parts[4])

}

@available(iOS 17, *)
public class SessionCache {
  public static let shared = SessionCache()
  
  private var sessions : [String: SessionData] = [:]
  private var lock = NSLock()
  private let defaults = UserDefaults(suiteName: defaultsSuiteName)
  private var sessionDelegateCreator: ((_ kind:String) -> SessionDelegate)?

  
  public func setSessionDelegateCreator(_ creator: @escaping ((_ kind:String) -> SessionDelegate))
  {
    self.sessionDelegateCreator = creator
  }
  
  func savePending()
  {
    if sessions.count == 0 {
      defaults?.removeObject(forKey: pendingKey)
    } else {
      let pending = sessions.values.map { data in
        data.session.configuration.identifier
      }
      defaults?.set(pending, forKey: pendingKey)
    }
  }
  
  public func loadPendingSessions()
  {
    debug("loading pending session")
    guard let sessionDelegateCreator = sessionDelegateCreator else {
      debug("no session delegate creator")
      return
    }
    guard let pending : [String] = defaults?.array(forKey: pendingKey) as? [String] else {
      debug("No pending sessions")
      return
    }
    for id in pending {
      guard let info = parseSessionId(id) else {
        debug("invalid session id '\(id)'")
        continue
      }
      debug("creating session for \(id)")
      let delegate = sessionDelegateCreator(info.kind)
      do {
        let signalK = try delegate.getSignalK(connection: info.connection) as? RESTSignalK
        
        guard let signalK else {
          debug("could not get connection for session id \(id)")
          return
        }
        if let value = signalK.createValue(info.type, path:info.path) {
          signalK.putValue(value, path: info.path, source: info.source)
          let _ = get(for: id, delegate: delegate)
        }
      } catch {
        debug("error loading session: \(error.localizedDescription)")
      }
    }
  }
  
  public func remove(for id: String) {
    lock.withLock {
      sessions.removeValue(forKey: id)
      savePending()
    }
  }
  
  public func exists(for id: String) -> Bool {
    lock.withLock {
      return sessions[id] != nil
    }
  }
  
  public func get(for id: String, delegate: URLSessionDelegate) -> SessionData {
    lock.withLock {
      if let session = sessions[id] { return session }
      
      let session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: id)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = false
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
      }()
      let data = SessionData(session: session)
      sessions[id] = data
      savePending()
      return data
    }
  }
}

@available(iOS 17, *)
open class SessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
  public let kind : String
  
  public var completion: (() -> Void)?
  
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    debug("urlSessionDidFinishEvents '\(session.configuration.identifier)")
    guard let completion = completion else {
      debug ("no cometion handler")
      return
    }
    Task.detached { @MainActor in
      completion()
    }
  }
  
  public init(kind: String) {
    self.kind = kind
  }
  
  open func getSignalK(connection:String) throws -> SignalKServer? {
    return nil
  }
  
  open func valueUpdated(path: String, value: SKValueBase) {
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)  {
    debug("didFinishDownloadingTo '\(session.configuration.identifier! ?? "unknown")")

    guard let id = session.configuration.identifier else { return }
    
    let data = try FileManager.default.contents(atPath: location.path)
    
    guard let data else {
      debug("could not read data for session id \(id)")
      return
    }

    //let sessionId = "\(self.connectionName)/\(path)/\(type)"

    let parts = id.components(separatedBy: "/")
    guard parts.count > 3 else {
      debug("invalid session id '\(id)'")
      return
    }
    
    let connection = parts[0],
    path = parts[1],
    source = parts[2],
    type = parts[3]
    
    do {
      let signalK = try getSignalK(connection: connection) as? RESTSignalK
      
      guard let signalK else {
        debug("could not get connection for session id \(id)")
        return
      }
      
      Task.detached { @MainActor in
        if let value = try signalK.setValueFromDownloadResponse(path: path, source:source, type: type, data: data) {
          self.valueUpdated(path: path, value: value)
        }
      }
    } catch {
      debug("Error updating value from session \(id) : \(error.localizedDescription)")
    }
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
    debug("didCompleteWithError '\(session.configuration.identifier! ?? "unknown") \(error)")
    SessionCache.shared.remove(for: session.configuration.identifier!)
    if error != nil {
      debug("Error for session \(session.configuration.identifier) : \(error?.localizedDescription)")
    }
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


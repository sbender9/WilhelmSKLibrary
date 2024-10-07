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
  let scheme: String, host: String, port: Int
  let restEndpoint: String
  let updateRate: Double
  var token : String?
  public var cacheAge : TimeInterval = 1.0
  
  var timer: Timer?
  
  public convenience init(host: String, updateRate: Double = 0 ) throws
  {
    guard let url = URL(string:host),
          let host = url.host,
          let scheme = url.scheme,
          let port = url.port
    else { throw SignalKError.invalidUrl }
    self.init(scheme:scheme, host: host, port: port, connectionName: "none", updateRate: updateRate)
  }
  
  /*
  public init(restEndpoint: String, connectionName:String, updateRate: Double = 0 )
  {
    self.restEndpoint = restEndpoint
    self.updateRate = updateRate
    super.init(connectionName: connectionName)
  }*/
  
  public init(scheme: String, host: String, port: Int, connectionName: String, updateRate: Double = 0) {
    self.restEndpoint = "\(scheme)://\(host):\(port)/signalk/v1/"
    self.updateRate = updateRate
    self.host = host
    self.scheme = scheme
    self.port = port
    
    super.init(connectionName: connectionName)
  }
  
  open func hasToken() -> Bool {
    return token != nil
  }
  
  func sendBackgroundHttpRequest(urlString: String, method: String, body:Any?, sessionId: String, delegate: URLSessionDelegate) throws {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let body = body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    
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
    
    debug("sending \(method) request for \(url)")
    
    let session = URLSession(configuration: .default)
    let (data, resp) = try await session.data(for:request)
    let status = (resp as! HTTPURLResponse).statusCode
    guard status != 401 else { throw SignalKError.unauthorized }
    guard status == 200 else { throw SignalKError.message("Invalid server response \(status)") }
    //debug(status)
    //debug(String(data: data, encoding: .utf8))
    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    //debug("reposonse from GET request: \(dict)")
    
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
  
  
  @MainActor
  private func updateVaue(_ value: SKValueBase) async throws -> Bool {
    
    if value.cached != nil && value.cached!.timeIntervalSinceNow > (cacheAge * -1) {
      return false
    }
    
    let path = value.info.path
    let urlString = "api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    
    //make so another call does get made
    value.cached = Date()
    
    do {
      //let theType = type(of: path)
      guard let info = try await sendGet(urlString) as? [String:Any] else { throw SignalKError.invalidServerResponse }
      //guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
      
      try setValueFromResponse(info: info, path: path)
      
      startTimer()
      return true
    } catch {
      debug("error update value \(error)")
    }
    return false
  }
  
  @MainActor
  func setValueFromDownloadResponse(path: String, source: String?, type: String, info: [String:Any]) throws
  {
    //let source = source == "nil" ? nil : source
    
    /*
    guard let info = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
      throw SignalKError.invalidServerResponse
    }*/
    //guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
    
    try setValueFromResponse(info: info, path: path)
  }
  
  @MainActor
  func setValueFromResponse(info: [String:Any], path:String ) throws
  {
    //guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
    let meta = info["meta"] as? [String: Any]
    
    if let values = info["values"] as? [String:[String:Any]]  {
      for (key, vmap) in values {
        setSKValue(vmap["value"], path: path, source: key, timestamp: vmap["timestamp"] as? String, meta: meta)
      }
    }
    setSKValue(info["value"], path: path, source: nil, timestamp: info["timestamp"] as? String, meta: meta)
  }
  
  //@MainActor
  private func updateValues() async {
    for value in getUniqueCachedValues().values {
      do {
        let _ = try await updateVaue(value)
      } catch {
        debug("error updatePath \(error)")
      }
    }
  }
  
  private func startTimer() {
    if timer == nil && updateRate > 0 {
      timer = Timer.scheduledTimer(withTimeInterval: updateRate, repeats: true) { [self] timer in
        Task {
          await updateValues()
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
    
    let req = PathRequest(path: path, type: String(describing: T.self), source: source)
    let res = getSelfPaths([req], delegate: delegate)
    return res[path] as! SKValue<T> //FIXME, check??
    
    /*
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    if value.cached != nil && value.cached!.timeIntervalSinceNow > (cacheAge * -1) {
      //FIME call delegate???
      debug("getSelfPath using cache for \(path)")
      return value
    }

    let path = value.info.path
    let urlString = "api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
        
    //make so another call does get made
    value.cached = Date()

    let type : String  = String(describing: T.self)
    let paths = "[{\"path\":\"\(path)\",\"type\":\"\(type)\"\(source != nil ? ",\"source\":\"\(source)\"" : "")}]"
    let sessionId = "\(self.connectionName!)/\(paths)/\(delegate.kind)"
    
    do {
      try sendBackgroundHttpRequest(urlString: urlString, method:"GET", body:nil, sessionId: sessionId, delegate: delegate)
    } catch {
      debug("getSelfPath error: \(error)")
    }
    
    return value
     */
  }
  
  override public func getSelfPaths(_ paths: [PathRequest], delegate: SessionDelegate) -> [String:SKValueBase]
  {
    var result : [String:SKValueBase] = [:]
    var needed : [[String:String?]] = []

    needed = paths.compactMap { pr in
      var value = cache.get(pr.path, source: pr.source, type: pr.type)
      if value == nil {
        if let val = createValue(pr.type, path:pr.path ) {
          setSKValue(val, path: pr.path, source: pr.source, timestamp: nil, meta: nil)
          value = val
          cache.put(val, path: pr.path, source: pr.source, type: pr.type)
        } else {
          value = SKValue(SKPathInfo(pr.path)) as SKValue<Any>
        }
      }
      if let value = value {
        result[pr.path] = value
        if value.cached != nil && value.cached!.timeIntervalSinceNow > (cacheAge * -1) {
          return nil
        } else {
          value.cached = Date()
          var res =  ["path": pr.path, "type": pr.type]
          if let source = pr.source { res["source"] = source }
          return res
        }
      }

      return nil
    }

    if needed.count > 0 {
      do {
        let urlString = "api/wsk/paths"
        let data = try JSONEncoder().encode(needed)
        let sessionId = "\(self.connectionName!)/\(String(data: data, encoding: .utf8)!)/\(delegate.kind)"
        
        try sendBackgroundHttpRequest(urlString: urlString, method:"POST", body:needed, sessionId: sessionId, delegate: delegate)
      } catch {
        debug("getSelfPaths error: \(error)")
      }
    }

    return result
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
  
  func processResponse(_ res: [String:Any], path: String,
                       completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void) {
    guard let state = res["state"] as? String,
          let statusCode = res["statusCode"] as? Int,
          let requestId = res["requestId"] as? String
    else {
      clearCache(path)
      completion(SignalKResponseState.failed, nil , res, SignalKError.invalidServerResponse)
      return
    }

    let skState = SignalKResponseState(rawValue: state) ?? SignalKResponseState.failed
    switch skState {
    case .completed:
      fallthrough
    case .failed:
      clearCache(path)
      completion(skState, statusCode, res, nil)

    default:
      /*
      guard let href = res["href"] as? String else {
        completion(nil, nil , res, SignalKError.invalidServerResponse)
        return
      }
       */
      clearCache(path)
      completion(skState, statusCode, res, nil)
      
      let _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
        Task {
          do {
            let res = try await self.sendGet("api/actions/\(requestId)")
            guard let res = res as? [String:Any]  else { throw SignalKError.invalidServerResponse }
            self.processResponse(res, path: path, completion: completion)
          } catch {
            self.clearCache(path)
            completion(SignalKResponseState.failed, nil, nil, error)
          }
        }
      }
    }
  }
  
  override open func putSelfPath(path: String, value: Any?, completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void ) {
    let urlString = "api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    Task {
      do {
        let res = try await sendPut(urlString, data: ["value": value]) as! [String:Any]
        processResponse(res, path:path, completion: completion)
      } catch {
        completion(SignalKResponseState.failed, nil, nil, error)
      }
    }
  }
  
  open func getToken() -> String? {
    return nil
  }
  
  open func getLogin() -> (username: String, password: String)? {
    return nil
  }
  
  override open func putSelfPath(path: String, value: Any?) async throws -> [String:Any] {
    let urlString = "api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    let res = try await sendPut(urlString, data: ["value": value]) as! [String:Any]
    clearCache(path)
    return res
  }
  
  open func login() async throws {
    if let login = getLogin() {
      let data = try JSONEncoder().encode(["username": login.username, "password": login.password])
      
      let res = try await sendHttpRequest(urlString: "auth/login", method: "POST", body: data) as? [String:Any]
      
      self.token = res?["token"] as? String
    }
  }
}

@available(iOS 17, *)
public struct SessionData {
  public var session : URLSession
}

private let defaultsSuiteName = "group.com.scottbender.wilhelm"
private let pendingKey = "pendingSessions"

private func parseSessionId(_ id: String) -> (connection: String, paths: [[String:String]], kind: String)?
{
  let parts = id.components(separatedBy: "/")
  guard parts.count == 3 else {
    debug("invalid session id '\(id)'")
    return nil
  }
  
  do {
    let paths = try JSONSerialization.jsonObject(with: parts[1].data(using: .utf8)!, options: []) as? [[String:String]]
    guard let paths = paths else {
      debug("invalid paths in session id '\(id)'")
      return nil
    }
    return (connection: parts[0],
            paths: paths,
            kind: parts[2])
    
  } catch {
    debug("invalid paths in session id '\(id)' \(error.localizedDescription)")
    return nil
  }
}

@available(iOS 17, *)
public class SessionCache {
  public static let shared = SessionCache()
  
  private var sessions : [String: SessionData] = [:]
  private var restoredSessions : [String: SessionData] = [:]
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
      debug("creating pending session for \(id)")
      let delegate = sessionDelegateCreator(info.kind)
      do {
        let signalK = try delegate.getSignalK(connection: info.connection) as? RESTSignalK
        
        guard let signalK else {
          debug("could not get connection for session id \(id)")
          return
        }
        for pi in info.paths {
          if let value = signalK.createValue(pi["type"]!, path:pi["path"]! ) {
            //signalK.setSKValue(value, path: info.path, source: info.source)
            signalK.setSKValue(value, path: pi["path"]!, source: pi["source"], timestamp: nil, meta: nil)
            value.cached = Date()
          }
        }
        //let _ = get(for: id, delegate: delegate)
        let session: URLSession = {
          let config = URLSessionConfiguration.background(withIdentifier: id)
          config.isDiscretionary = false
          config.sessionSendsLaunchEvents = false
          return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }()
        let data = SessionData(session: session)
        restoredSessions[id] = data
      } catch {
        debug("error loading session: \(error.localizedDescription)")
      }
    }
    defaults?.removeObject(forKey: pendingKey)
  }
  
  public func remove(for id: String) {
    lock.lock()
    sessions.removeValue(forKey: id)
    restoredSessions.removeValue(forKey: id)
    savePending()
    lock.unlock()
  }
  
  public func exists(for id: String) -> Bool {
    lock.lock()
    return restoredSessions[id] != nil
    lock.unlock()

  }
  
  public func get(for id: String) -> SessionData? {
    lock.lock()
    return restoredSessions[id]
    lock.unlock()
  }
  
  public func get(for id: String, delegate: URLSessionDelegate) -> SessionData {
    lock.lock()
    if let session = sessions[id] { lock.unlock(); return session }
    
    debug("create session for \(id)")
      
    let session: URLSession = {
      let config = URLSessionConfiguration.background(withIdentifier: id)
      config.isDiscretionary = false
      config.sessionSendsLaunchEvents = false
      return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
    let data = SessionData(session: session)
    sessions[id] = data
    savePending()
    lock.unlock()
    return data
  }
}

@available(iOS 17, *)
open class SessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
  public let kind : String
  
  public var completion: (() -> Void)?
  
  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    debug("urlSessionDidFinishEvents '\(session.configuration.identifier!)")
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
  
  open func valueUpdated() {
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)  {
    debug("didFinishDownloadingTo '\(session.configuration.identifier!)")

    guard let id = session.configuration.identifier else { return }
    
    let data = FileManager.default.contents(atPath: location.path)
    
    guard let data else {
      debug("could not read data for session id \(id)")
      return
    }
    

    //let sessionId = "\(self.connectionName)/\(path)/\(type)"
    guard let info = parseSessionId(id) else {
      debug("invalid session id '\(id)'")
      return
    }

    do {
      let signalK = try getSignalK(connection: info.connection) as? RESTSignalK
      
      guard let signalK else {
        debug("could not get connection for session id \(id)")
        return
      }
      
      guard let dict : [String:[String:Any]] = try JSONSerialization.jsonObject(with: data, options: []) as? [String:[String:Any]]
      else {
        debug("could not decode response \(id)")
        return
      }
      
      Task.detached { @MainActor in
        for pi in info.paths {
          let path =  pi["path"]!
          if let value = dict[path] as? [String:Any] {
            try signalK.setValueFromDownloadResponse(path: path, source:pi["source"], type: pi["type"]!, info: value)
          } else {
            debug("invalid value \(id)")
          }
        }
        self.valueUpdated()
      }
    } catch {
      debug("Error updating value from session \(id) : \(error.localizedDescription)")
    }
  }
  
  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
    debug("didCompleteWithError '\(session.configuration.identifier!) Error: \(String(describing: error))")
    SessionCache.shared.remove(for: session.configuration.identifier!)
  }
  
}

@available(iOS 16, *)
public enum SignalKError: LocalizedError {
  case invalidType
  case invalidServerResponse
  case unauthorized
  case invalidUrl
  case message(_ message: String)
  
  public var localizedStringResource: LocalizedStringResource {
    switch self {
    case let .message(message): return "\(message)"
    case .invalidType: return "Invalid type"
    case .invalidServerResponse: return "Invalid server response"
    case .unauthorized: return "Permission Denied"
    case .invalidUrl: return "Invalid URL"
    }
  }
  
  public var errorDescription: String? {
    switch self {
    case let .message(message): return "\(message)"
    case .invalidType: return "Invalid type"
    case .invalidServerResponse: return "Invalid server response"
    case .unauthorized: return "Permission Denied"
    case .invalidUrl: return "Invalid URL"
    }
  }
  
}

public enum SignalKResponseState: String {
  case completed = "COMPLETED"
  case failed = "FAILED"
  case pending = "PENDING"
}


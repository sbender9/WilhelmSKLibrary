//
//  SignalK.swift
//  WilhelmSK
//
//  Created by Scott Bender on 9/22/24.
//  Copyright © 2024 Scott Bender. All rights reserved.
//

import Foundation
import Combine

private let putCheckInterval = 1.0
private let putCheckRetryCount = 8

@available(iOS 17, *)
open class RESTSignalK : SignalKBase, URLSessionDelegate {
  var scheme: String, host: String, port: Int
  var restEndpoint: String
  var updateRate: Double
  open var token : String?
  public var cacheAge : TimeInterval = 1.0
  public var shouldUpdateValues = true
  
  //private var tasks : [URLSessionDownloadTask] = []
  
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
    self.restEndpoint = "\(scheme)://\(host):\(port)/"
    self.host = host
    self.scheme = scheme
    self.port = port
    self.updateRate = updateRate

    super.init(connectionName: connectionName)
  }
  
  open func updateConnectionInfo(scheme: String, host: String, port: Int) {
    self.restEndpoint = "\(scheme)://\(host):\(port)/"
    self.host = host
    self.scheme = scheme
    self.port = port
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
    
    debug("sending background \(method) request for \(url)")
    
    let task = sessionData.session.downloadTask(with:request)
    //task.countOfBytesClientExpectsToSend = 0
    //task.countOfBytesClientExpectsToReceive = 1024
    task.resume()
    //tasks.append(task)
  }
  
  
  //@MainActor
  func sendHttpRequest(urlString: String, method: String, body: Any?) async throws -> Data {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { throw SignalKError.invalidUrl }
    var request = URLRequest(url: url)
    request.httpMethod = method
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    debug("sending \(method) requeest for \(url)")
    
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 10
    sessionConfig.timeoutIntervalForResource = 10
    let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)

    let data :Data, resp: URLResponse
    do {
      (data, resp) = try await session.data(for:request)
    } catch {
      throw SignalKError.message(error.localizedDescription)
    }

    let status = (resp as! HTTPURLResponse).statusCode
    guard status != 401 else { throw SignalKError.unauthorized }

    if status == 404 && urlString.contains("/api/wsk/push/") {
      throw SignalKError.needsPushPlugin
    } else if status == 404 && urlString.contains("/api/wsk/") {
      throw SignalKError.needsWilhelmSKPlugin
    }
    guard status != 404 else { throw SignalKError.notFound }
    guard status == 200 else { throw SignalKError.message("Invalid server response \(status)") }
    //debug(status)
    //debug(String(data: data, encoding: .utf8))
    
    //let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    //debug("reposonse from GET request: \(dict)")
    
    return data
  }

  public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
    let protectionSpace = challenge.protectionSpace
    
    guard let serverTrust = protectionSpace.serverTrust else {
      return (.performDefaultHandling, nil)
    }
    let credential = URLCredential(trust: serverTrust)
    return (.useCredential, credential)
  }
    
  //@MainActor
  func sendHttpRequestIgnoringStatus(urlString: String, method: String, body: Data?) async throws -> Any? {
    guard let url = URL(string: "\(restEndpoint)\(urlString)") else { return nil }
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.httpBody = body
    
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 10
    sessionConfig.timeoutIntervalForResource = 10
    let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    let (data, resp) = try await session.data(for: request)
    
    let status = (resp as! HTTPURLResponse).statusCode
    guard status != 401 else { throw SignalKError.unauthorized }
    guard status != 404 else { throw SignalKError.notFound }

    guard status == 200 || status == 202 else { throw SignalKError.message("Invalid server response \(status)") }

    
    let dict = try JSONSerialization.jsonObject(with: data, options: [])
    
    return dict
  }
  
  //@MainActor
  public func sendGet(_ urlString: String) async throws -> Any?
  {
    let data = try await sendHttpRequest(urlString: urlString, method: "GET", body: nil)
    return try JSONSerialization.jsonObject(with: data, options: [])
  }
  
  //@MainActor
  func sendPut(_ urlString: String, data: Any) async throws -> Any? {
    guard JSONSerialization.isValidJSONObject(data) else { throw SignalKError.message("invalid put data") }
    let putData = try JSONSerialization.data(withJSONObject: data)
    return try await sendHttpRequestIgnoringStatus(urlString: urlString, method: "PUT", body: putData)
  }
  
  public func sendPost(_ urlString: String, body: Any?) async throws -> Any?
  {
    return try await sendHttpRequest(urlString: urlString, method: "POST", body: body)
  }
  
  
  @MainActor
  private func updateVaue(_ value: SKValueBase) async throws -> Bool {
    
    guard shouldUpdateValues else { return true }
    
    if value.cached != nil && value.cached!.timeIntervalSinceNow > (cacheAge * -1) {
      return false
    }
    
    let path = value.info.path
    let urlString = "signalk/v1/api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    
    //make so another call does get made
    value.cached = Date()
    
    //do {
      guard let info = try await sendGet(urlString) as? [String:Any] else { throw SignalKError.invalidServerResponse }
      //guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
      
      try setValueFromResponse(info: info, path: path)
      
      startTimer()
      return true
    /*
    } catch {
      debug("error update value \(error)")
    }
    return false
     */
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
  func setValueFromResponse(info: [String:Any]?, path:String ) throws
  {
    var meta : [String:Any]? = nil
    if let info {
      //guard let source = info["$source"] as? String else { throw SignalKError.invalidServerResponse }
      meta = info["meta"] as? [String: Any]
      
      if let values = info["values"] as? [String:[String:Any]]  {
        for (key, vmap) in values {
          setSKValue(vmap["value"], path: path, source: key, timestamp: vmap["timestamp"] as? String, meta: meta)
        }
      }
      let value = info.index(forKey: "value") != nil ? info["value"] : info
      setSKValue(value, path: path, source: nil, timestamp: info["timestamp"] as? String, meta: meta)
    } else {
      setSKValue(nil, path: path, source: nil, timestamp: nil, meta: meta)
    }
  }
  
  //@MainActor
  private func updateValues() async {
    
    guard shouldUpdateValues else { return }

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
    
    if shouldUpdateValues {
      Task {
        do {
          let _ = try await updateVaue(value)
        } catch {
          debug("error getObservableSelfPath \(error)")
        }
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
  
  override public func getSelfPaths(_ paths: [PathRequest]) async throws -> [String:SKValueBase] {
    var result : [String:SKValueBase] = [:]
    var needed : [PathRequest]
    
    needed = paths.compactMap { pr in
      var value = cache.get(pr.path, source: pr.source, type: pr.type)
      if value == nil {
        if let val = Self.createValue(pr.type, path:pr.path ) {
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
          return pr
        }
      }
      
      return nil
    }
    
    guard shouldUpdateValues else { return result }
    
    if needed.count > 0 {
      let urlString = "signalk/v1/api/wsk/paths"
      
      var post : [[String:String?]] = needed.map { pr in
        var res =  ["path": pr.path, "type": pr.type]
        if let source = pr.source {
          res["source"] = source
        }
        return res
      }
      //let data = try JSONEncoder().encode(post)
      
      do {
        let data = try await sendHttpRequest(urlString: urlString, method:"POST", body:post)
        guard let info = try JSONSerialization.jsonObject(with: data, options: []) as? [String:[String:Any]]
        else { throw SignalKError.invalidServerResponse }

        for pr in needed {
          let path =  pr.path
          let value = info[path] as? [String:Any]
          try await setValueFromResponse(info: value, path: path)
        }
      } catch {
        //make so we try again and display errors on the front end
        for val in result.values {
          val.cached = nil
        }
        throw error
      }
    }
    
    return result
  }

  
  override public func getSelfPath<T>(_ path: String, source: String?, uuid: String, delegate: SessionDelegate) -> SKValue<T> {
    
    let req = PathRequest(path: path, type: String(describing: T.self), source: source)
    let res = getSelfPaths([req], uuid: uuid, delegate: delegate)
    return res[path] as! SKValue<T> //FIXME, check??
  }
  
  override public func getSelfPaths(_ paths: [PathRequest], uuid: String, delegate: SessionDelegate) -> [String:SKValueBase]
  {
    var result : [String:SKValueBase] = [:]
    var needed : [PathRequest]

    needed = paths.compactMap { pr in
      var value = cache.get(pr.path, source: pr.source, type: pr.type)
      if value == nil {
        if let val = Self.createValue(pr.type, path:pr.path ) {
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
          return pr
        }
      }

      return nil
    }
    
    delegate.signalK = self
    delegate.paths = paths

    if needed.count > 0 {
      do {
        let urlString = "signalk/v1/api/wsk/paths"
        let data = try JSONEncoder().encode(needed)
        
        var post : [[String:String?]] = needed.map { pr in
          var res =  ["path": pr.path, "type": pr.type]
          if let source = pr.source {
            res["source"] = source
          }
          return res
        }
        
        try sendBackgroundHttpRequest(urlString: urlString, method:"POST", body:post, sessionId: uuid, delegate: delegate)
      } catch {
        debug("getSelfPaths error: \(error)")
      }
    }

    return result
  }

  
  override public func getSelfPath<T>(_ path: String, source: String?, completion: @escaping (Bool, SKValueBase, Error?) -> Void) -> SKValue<T> {
    let value : SKValue<T> = getOrCreateValue(path, source: source)
    
    if shouldUpdateValues {
      Task.detached { @MainActor in
        do {
          let updated = try await self.updateVaue(value)
          completion(updated, value, nil)
        } catch {
          completion(false, value, error)
        }
      }
    } else {
      completion(true, value, nil)
    }
    
    return value
  }
  
  func processResponse(_ res: [String:Any],
                       path: String,
                       multipleCallbacks: Bool,
                       repeatCount: Int,
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
        
      case .pending:
        /*
         guard let href = res["href"] as? String else {
         completion(nil, nil , res, SignalKError.invalidServerResponse)
         return
         }
         */
        clearCache(path)
        
        if multipleCallbacks {
          completion(skState, statusCode, res, nil)
        }
        
        //FIXME: needs to eventually timeout
        
        guard repeatCount != putCheckRetryCount else {
          completion(SignalKResponseState.failed, nil, nil, SignalKError.message("put request timed out"))
          return
        }
        
        DispatchQueue.main.async {
          let _ = Timer.scheduledTimer(withTimeInterval: putCheckInterval, repeats: false) { timer in
            Task {
              do {
                let res = try await self.sendGet("signalk/v1/requests/\(requestId)")
                guard let res = res as? [String:Any]  else { throw SignalKError.invalidServerResponse }
                self.processResponse(res, path: path, multipleCallbacks: multipleCallbacks, repeatCount: repeatCount+1, completion: completion)
              } catch {
                self.clearCache(path)
                completion(SignalKResponseState.failed, nil, nil, error)
              }
            }
          }
        }
    }
  }
  
  override open func putSelfPath(path: String, value: Any?, completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void ) {
    putSelfPath(path: path, value: value, multipleCallbacks: true, completion: completion)
  }
  
  private func putSelfPath(path: String, value: Any?, multipleCallbacks: Bool, completion: @escaping (SignalKResponseState, Int?, [String:Any]?, Error?) -> Void ) {
    let urlString = "signalk/v1/api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    Task {
      do {
        let data = ["value": value]
        let res = try await sendPut(urlString, data: data) as! [String:Any]
        processResponse(res, path:path, multipleCallbacks: multipleCallbacks, repeatCount: 0, completion: completion)
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
  
  open func oldputSelfPath(path: String, value: Any?) async throws -> (SignalKResponseState, Int, [String:Any]) {
    let urlString = "signalk/v1/api/vessels/self/\(path.replacingOccurrences(of: ".", with: "/"))"
    let res = try await sendPut(urlString, data: ["value": value]) as! [String:Any]
    clearCache(path)
    
    guard let state = res["state"] as? String,
          let statusCode = res["statusCode"] as? Int,
          let requestId = res["requestId"] as? String
    else {
      throw SignalKError.invalidServerResponse
    }
  
    let skState = SignalKResponseState(rawValue: state) ?? SignalKResponseState.failed
    
    let message = res["message"] as? String
    
    switch skState {
      case .completed:
        if statusCode != 200 {
          throw SignalKError.message(message ?? "Unknown error \(statusCode)")
        }
        return (skState, statusCode, res)
      case .pending:
        return (skState, statusCode, res)

      case .failed:
        throw SignalKError.message(message ?? "Unknown error \(statusCode)")
    }
  }
  
  override open func putSelfPath(path: String, value: Any?) async throws -> (SignalKResponseState, Int?, [String:Any]?) {
    return try await withCheckedThrowingContinuation  { continuation in

      self.putSelfPath(path: path, value: value, multipleCallbacks: false) { state, statusCode, res, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: (state, statusCode, res))
        }
      }

    }
  }
  
  func didPutPath(_ path: String, withError error: (any Error)?, userInfo: [AnyHashable : Any] = [:]) {
    let continuation = userInfo["continuation"] as! CheckedContinuation<Void, Error>
    self.clearCache(path)
    guard error == nil else {
      continuation.resume(throwing: error!)
      return
    }
    continuation.resume()
  }

  
  open func login() async throws {
    if let login = getLogin() {
      let post = ["username": login.username, "password": login.password]
      
      let data = try await sendHttpRequest(urlString: "signalk/v1/auth/login", method: "POST", body: post)
      let res = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]

      self.token = res?["token"] as? String
    }
  }
}

@available(iOS 17, *)
public struct SessionData {
  public var session : URLSession
  public var delegate: URLSessionDelegate
}

private let defaultsSuiteName = "group.com.scottbender.wilhelm"
private let pendingKey = "pendingSessionsV2"

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
  
  public func getPendingSessions() -> [String]
  {
    guard let pending : [String] = defaults?.array(forKey: pendingKey) as? [String] else {
      return []
    }
    return pending
  }
  
  public func loadPendingSessions(delegates: [String: SessionDelegate])
  {
    debug("loading pending session")
    guard let pending : [String] = defaults?.array(forKey: pendingKey) as? [String] else {
      debug("No pending sessions")
      return
    }
    for id in pending {
      debug("creating pending session for \(id)")
      guard let delegate = delegates[id] else {
        debug("no delegate for session id \(id)")
        continue
      }
      do {
        //let signalK = try delegate.getSignalK(connection: info.connection) as? RESTSignalK
        
        guard let signalK = delegate.signalK else {
          debug("could not get connection for session id \(id)")
          return
        }
        
        guard let paths = delegate.paths else {
          debug("no paths for session id \(id)")
          return
        }
        
        for pi in paths {
          if let value = SignalKBase.createValue(pi.type, path:pi.path ) {
            //signalK.setSKValue(value, path: info.path, source: info.source)
            signalK.setSKValue(value, path: pi.path, source: pi.source, timestamp: nil, meta: nil)
            value.cached = Date()
          }
        }
        //let _ = get(for: id, delegate: delegate)
        let session: URLSession = {
          let config = URLSessionConfiguration.background(withIdentifier: id)
          config.isDiscretionary = false
          config.sessionSendsLaunchEvents = true
          return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        }()
        let data = SessionData(session: session, delegate: delegate)
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
      config.sessionSendsLaunchEvents = true
      return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }()
    let data = SessionData(session: session, delegate: delegate)
    sessions[id] = data
    savePending()
    lock.unlock()
    return data
  }
}

@available(iOS 17, *)
open class SessionDelegate: NSObject, URLSessionDelegate, URLSessionDownloadDelegate {
  public var signalK: RESTSignalK? = nil
  public var paths: [PathRequest]? = nil
  
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

  open func valueUpdated(sessionId: String) {
  }
  
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL)  {
    debug("didFinishDownloadingTo '\(session.configuration.identifier!)")

    guard let id = session.configuration.identifier else { return }
    
    let data = FileManager.default.contents(atPath: location.path)
    
    guard let data else {
      debug("could not read data for session id \(id)")
      return
    }
    
    /*
    //let sessionId = "\(self.connectionName)/\(path)/\(type)"
    guard let info = parseSessionId(id) else {
      debug("invalid session id '\(id)'")
      return
    }
     */

    do {
      Task.detached { @MainActor in
                
        guard let signalK = self.signalK else {
          debug("could not get connection for session id \(id)")
          return
        }
        
        guard let paths = self.paths else {
          debug("could not get paths for session id \(id)")
          return
        }
        
        guard let dict : [String:[String:Any]] = try JSONSerialization.jsonObject(with: data, options: []) as? [String:[String:Any]]
        else {
          debug("could not decode response \(id)")
          return
        }
        
        for pi in paths {
          let path =  pi.path
          if let value = dict[path] as? [String:Any] {
            try signalK.setValueFromDownloadResponse(path: path, source:pi.source, type: pi.type, info: value)
          } else {
            debug("invalid value \(id)")
          }
        }
        self.valueUpdated(sessionId: id)
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
public enum SignalKError: LocalizedError, CustomLocalizedStringResourceConvertible {
  case invalidType
  case invalidServerResponse
  case unauthorized
  case invalidUrl
  case needsWilhelmSKPlugin
  case needsPushPlugin
  case notFound
  case message(_ message: String)
  
  public var localizedStringResource: LocalizedStringResource {
    switch self {
      case let .message(message): return "\(message)"
      case .invalidType: return "Invalid type"
      case .invalidServerResponse: return "Invalid server response"
      case .unauthorized: return "Permission Denied"
      case .invalidUrl: return "Invalid URL"
      case .needsWilhelmSKPlugin: return "Please install and enable the WilhelmSK Plugin"
      case .needsPushPlugin: return "Please install and enable the signalk-push-plugin"
      case .notFound: return "Path not found"
    }
  }
  
  public var errorDescription: String? {
    switch self {
      case let .message(message): return "\(message)"
      case .invalidType: return "Invalid type"
      case .invalidServerResponse: return "Invalid server response"
      case .unauthorized: return "Permission Denied"
      case .invalidUrl: return "Invalid URL"
      case .needsWilhelmSKPlugin: return "Please install and enable the WilhelmSK Plugin"
      case .needsPushPlugin: return "Please install and enable the signalk-push-plugin"
      case .notFound: return "Path not found"
    }
  }
  
}

public enum SignalKResponseState: String {
  case completed = "COMPLETED"
  case failed = "FAILED"
  case pending = "PENDING"
}


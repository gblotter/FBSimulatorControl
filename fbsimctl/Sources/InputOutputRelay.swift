/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

import Foundation

/**
 A class for translating stdin to stdout & stderr.
*/
protocol InputOutputRelay {
  func start()
  func stop()
}

class SignalHandler {
  let callback: String -> Void
  var sources: [dispatch_source_t] = []
  
  init(callback: String -> Void) {
    self.callback = callback
  }
  
  private func register() {
    let signalPairs: [(Int32, String)] = [
      (SIGTERM, "SIGTERM"),
      (SIGHUP, "SIGHUP"),
      (SIGINT, "SIGINT")
    ]
    self.sources = signalPairs.map { (signal, name) in
      let source = dispatch_source_create(
        DISPATCH_SOURCE_TYPE_SIGNAL,
        UInt(signal), 
        0,
        dispatch_get_main_queue()
      )
      dispatch_source_set_event_handler(source) {
        self.callback(name)
      }
      dispatch_resume(source)
      return source
    }
  }
  
  private func unregister() {
    for source in self.sources {
      dispatch_source_cancel(source)
    }
  }
}

extension SignalHandler {
  static func runUntilSignalled() {
    var signalled = false
    let handler = SignalHandler { signalName in
      print("Signalled by \(signalName)")
      signalled = true
    }
    
    handler.register()
    NSRunLoop.currentRunLoop().spinRunLoopWithTimeout(DBL_MAX) { signalled }
    handler.unregister()
  }
}

class StdIORelay : InputOutputRelay {
  let transform: (String, Int) -> Output
  
  let stdIn: NSFileHandle
  let stdOut: NSFileHandle
  let stdErr: NSFileHandle
  
  var buffer: String
  
  init(transform: (String, Int) -> Output) {
    self.transform = transform
    self.stdIn = NSFileHandle.fileHandleWithStandardInput()
    self.stdOut = NSFileHandle.fileHandleWithStandardOutput()
    self.stdErr = NSFileHandle.fileHandleWithStandardError()
    self.buffer = ""
  }
  
  func start() {
    self.stdIn.readabilityHandler = { handle in
      let data = handle.availableData
      let string = String(data: data, encoding: NSUTF8StringEncoding)!

      self.buffer.appendContentsOf(string)
      self.runBuffer()
    }
    SignalHandler.runUntilSignalled()
  }
  
  func stop() {
    self.stdIn.readabilityHandler = nil
  }
  
  private func runBuffer() {
    let buffer = self.buffer
    let lines = buffer
      .componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
      .filter { line in
        line != ""
      }
    if (lines.isEmpty) {
      return
    }
    
    self.buffer = ""
    dispatch_sync(dispatch_get_main_queue()) {
      for line in lines {
        let result = self.transform(line, 0)
        switch (result) {
        case .Success(let string):
          self.writeOut(string)
        case .Failure(let string):
          self.writeErr(string)
        }
      }
    }
  }
  
  private func writeOut(string: String) {
    self.write(string, handle: self.stdOut)
  }
  
  private func writeErr(string: String) {
    self.write(string, handle: self.stdErr)
  }
  
  private func write(var string: String, handle: NSFileHandle) {
    if (string.characters.last != "\n") {
      string.append("\n" as Character)
    }
    let data = string.dataUsingEncoding(NSUTF8StringEncoding)!
    handle.writeData(data)
  }
}

func acceptCallback(socket: CFSocket!, callback: CFSocketCallBackType, data: CFData!, pointer1: UnsafePointer<Void>, pointer2: UnsafeMutablePointer<Void>) -> Void {
  if callback != CFSocketCallBackType.AcceptCallBack {
    return
  }
  
  var readStreamPointer: Unmanaged<CFReadStream>? = nil
  var writeStreamPointer: Unmanaged<CFWriteStream>? = nil
  
  CFStreamCreatePairWithSocket(
    kCFAllocatorDefault,
    CFSocketGetNative(socket),
    &readStreamPointer,
    &writeStreamPointer
  )
  
  let readStream = readStreamPointer?.takeRetainedValue()
  let writeStream = readStreamPointer?.takeRetainedValue()

  let connection = SocketConnection(readStream: readStream!, writeStream: writeStream!)
  print(connection)
}

struct SocketConnection {
  let readStream: NSInputStream
  let writeStream: NSInputStream
}

struct SocketRelayOptions {
  let portNumber: Int
  let bindIPv4: Bool
  let bindIPv6: Bool
}

class SocketRelay : NSObject, InputOutputRelay, NSPortDelegate  {
  let options: SocketRelayOptions
  let transform: (String, Int) -> Output
  
  init(portNumber: Int, transform: (String, Int) -> Output) {
    self.transform = transform
    self.options = SocketRelayOptions(portNumber: portNumber, bindIPv4: true, bindIPv6: false)
  }
  
  func start() {
    foo()
    SignalHandler.runUntilSignalled()
  }
  
  func socketContext() -> CFSocketContext {
    return CFSocketContext(
      version: 0, 
      info: nil,
      retain: nil,
      release: nil,
      copyDescription: nil
    )
  }

  func createSocket4() -> CFSocket {
    let sock = CFSocketCreate(
      kCFAllocatorDefault,
      PF_INET,
      SOCK_STREAM,
      IPPROTO_TCP,
      CFSocketCallBackType.AcceptCallBack.rawValue,
      acceptCallback,
      nil
    )
    
    var addr = sockaddr_in()
    memset(&addr, 0, strideof(sockaddr_in))
    addr.sin_len = UInt8(strideof(sockaddr_in))
    addr.sin_family = UInt8(AF_INET)
    addr.sin_port = UInt16(self.options.portNumber.bigEndian)
    addr.sin_addr.s_addr = 0
    
    let data: CFDataRef = NSData(bytes: &addr, length: strideof(sockaddr_in))
    let error = CFSocketSetAddress(sock, data)
    assert(error == CFSocketError.Success, "Could not bind ipv4")
    
    return sock
  }
  
  func createSocket6() -> CFSocket {
    let sock = CFSocketCreate(
      kCFAllocatorDefault,
      PF_INET6,
      SOCK_STREAM,
      IPPROTO_TCP,
      CFSocketCallBackType.AcceptCallBack.rawValue,
      acceptCallback,
      nil
    )
    
    var addr = sockaddr_in6()
    memset(&addr, 0, strideof(sockaddr_in6))
    addr.sin6_len = UInt8(strideof(sockaddr_in6))
    addr.sin6_family = UInt8(AF_INET6)
    addr.sin6_port = UInt16(self.options.portNumber.bigEndian)
    addr.sin6_addr = in6addr_any
    
    let data: CFDataRef = NSData(bytes: &addr, length: strideof(sockaddr_in6))
    let error = CFSocketSetAddress(sock, data)
    assert(error == CFSocketError.Success, "Could not bind ipv6")
    
    return sock
  }
  
  func foo() {
    var sockets: [CFSocket] = []
    
    if (self.options.bindIPv4) {
      sockets.append(createSocket4())
    }
    if (self.options.bindIPv6) {
      sockets.append(createSocket6())
    }
    
    for socket in sockets {
      let source = CFSocketCreateRunLoopSource(
        kCFAllocatorDefault,
        socket,
        0
      )
      CFRunLoopAddSource(
        CFRunLoopGetCurrent(),
        source,
        kCFRunLoopDefaultMode
      )

      let native = CFSocketGetNative(socket)
      print("Native socket of \(native)")
      assert(native != 0, "Couldn't get native socket")
    }
  }
  
  func stop() {
  }
  
  @objc internal func handlePortMessage(message: NSPortMessage) {
    print(message)
  }
  
  private func acceptConnection(notification: NSNotification) {
    let handle = notification.userInfo![NSFileHandleNotificationFileHandleItem]
    assert(handle != nil, "NO")
  }
}

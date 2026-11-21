// The native macOS brightness indicator, shown on any screen.
//
// Ported from MonitorControl's OSDUtils.swift
// Copyright © MonitorControl. @victorchabbert, @JoniVR, @theOneyouseek, @waydabber and others. MIT, see NOTICE.
// Changes: brightness only; the protocol is declared in Swift and OSD.framework is loaded at run
// time, so no bridging header is needed.

import AppKit
import os.log

@objc(OSDUIHelperProtocol) protocol OSDUIHelperProtocol {
  func showImage(_ image: Int64, onDisplayID: UInt32, priority: UInt32, msecUntilFade: UInt32,
                 filledChiclets: UInt32, totalChiclets: UInt32, locked: Bool)
}

enum OSD {
  private static let brightnessImage: Int64 = 1
  private static var connection: NSXPCConnection?

  /// Shows the brightness indicator on `displayID`, filled to `value` (0...1) in 16 steps.
  static func showBrightness(_ value: Double, on displayID: CGDirectDisplayID) {
    let filled = UInt32((value * 16).rounded())
    let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    if major >= 26, major <= 27 {
      helper()?.showImage(brightnessImage, onDisplayID: displayID, priority: 0x1F4, msecUntilFade: 1000,
                          filledChiclets: filled, totalChiclets: 16, locked: false)
    } else {
      legacyShow(filled: filled, displayID: displayID)
    }
  }

  // macOS 26 and 27: talk to the indicator service directly.
  private static func helper() -> OSDUIHelperProtocol? {
    if connection == nil {
      let c = NSXPCConnection(machServiceName: "com.apple.OSDUIHelper", options: [])
      c.remoteObjectInterface = NSXPCInterface(with: OSDUIHelperProtocol.self)
      c.interruptionHandler = { DispatchQueue.main.async { connection?.invalidate(); connection = nil } }
      c.invalidationHandler = { DispatchQueue.main.async { connection = nil } }
      c.resume()
      connection = c
    }
    return connection?.remoteObjectProxyWithErrorHandler { error in
      os_log("OSD helper error: %{public}@", type: .error, error.localizedDescription)
    } as? OSDUIHelperProtocol
  }

  // Other versions: OSD.framework's OSDManager, called through the Objective-C runtime.
  private static func legacyShow(filled: UInt32, displayID: CGDirectDisplayID) {
    _ = dlopen("/System/Library/PrivateFrameworks/OSD.framework/OSD", RTLD_NOW)
    guard let cls = NSClassFromString("OSDManager") as? NSObject.Type,
          let manager = cls.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue(),
          let send = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend") else { return }
    typealias Show = @convention(c) (AnyObject, Selector, Int64, UInt32, UInt32, UInt32, UInt32, UInt32, Bool) -> Void
    let selector = NSSelectorFromString("showImage:onDisplayID:priority:msecUntilFade:filledChiclets:totalChiclets:locked:")
    guard (manager as AnyObject).responds(to: selector) else { return }
    unsafeBitCast(send, to: Show.self)(manager as AnyObject, selector, brightnessImage, displayID, 0x1F4, 1000, filled, 16, false)
  }
}

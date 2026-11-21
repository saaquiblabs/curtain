// Apple's undocumented display functions, looked up at run time.
//
// None of these are in the public SDK, so we can't link against them. Looking each one up by
// name means a missing function turns one feature off instead of crashing the app. The
// declarations match the ones MonitorControl ships in its bridging header (MIT, see NOTICE),
// except those marked "Curtain:", which are Curtain's own.

import CoreGraphics
import Foundation
import IOKit

private func load(_ path: String) -> UnsafeMutableRawPointer? { dlopen(path, RTLD_NOW) }
private func symbol<T>(_ lib: UnsafeMutableRawPointer?, _ name: String, as _: T.Type) -> T? {
  guard let lib, let sym = dlsym(lib, name) else { return nil }
  return unsafeBitCast(sym, to: T.self)
}

private let coreGraphics = load("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
private let ioKit = load("/System/Library/Frameworks/IOKit.framework/IOKit")
private let coreDisplay = load("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay")
private let displayServices = load("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices")

enum Private {
  // Curtain: tells macOS to treat a display as unplugged (false) or plugged back in (true).
  static let configureDisplayEnabled = symbol(coreGraphics, "CGSConfigureDisplayEnabled",
    as: (@convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError).self)

  // DDC on Apple silicon: an I2C channel to the monitor's own controls.
  static let avServiceCreateWithService = symbol(ioKit, "IOAVServiceCreateWithService",
    as: (@convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?).self)
  static let avServiceReadI2C = symbol(ioKit, "IOAVServiceReadI2C",
    as: (@convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn).self)
  static let avServiceWriteI2C = symbol(ioKit, "IOAVServiceWriteI2C",
    as: (@convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutableRawPointer, UInt32) -> IOReturn).self)

  // EDID details for a display, used to pair a display with its DDC channel.
  static let displayCreateInfoDictionary = symbol(coreDisplay, "CoreDisplay_DisplayCreateInfoDictionary",
    as: (@convention(c) (CGDirectDisplayID) -> Unmanaged<CFDictionary>?).self)

  // Built-in (and Apple-made) display brightness.
  static let getBrightness = symbol(displayServices, "DisplayServicesGetBrightness",
    as: (@convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32).self)
  static let setBrightness = symbol(displayServices, "DisplayServicesSetBrightness",
    as: (@convention(c) (CGDirectDisplayID, Float) -> Int32).self)
  static let canChangeBrightness = symbol(displayServices, "DisplayServicesCanChangeBrightness",
    as: (@convention(c) (CGDirectDisplayID) -> Bool).self)
  // Curtain: tells us whenever an Apple screen's brightness changes, whoever changed it (F1/F2,
  // Control Centre, auto-brightness). The observer comes back to the callback; userInfo["value"].
  static let registerForBrightnessChanges = symbol(displayServices, "DisplayServicesRegisterForBrightnessChangeNotifications",
    as: (@convention(c) (CGDirectDisplayID, UnsafeRawPointer?, CFNotificationCallback) -> Int32).self)
}

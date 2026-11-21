// Brightness keys for external screens, and the one global shortcut.

import AppKit
import ApplicationServices
import Carbon.HIToolbox

final class Keys: ObservableObject {
  static let shared = Keys()

  @Published var brightnessKeys: Bool {
    didSet { UserDefaults.standard.set(brightnessKeys, forKey: "brightnessKeys"); update() }
  }
  /// True when brightness keys are on but macOS hasn't granted Accessibility yet.
  @Published private(set) var needsPermission = false

  private var tap: CFMachPort?
  private var source: CFRunLoopSource?
  private var permissionTimer: Timer?
  private var hotKey: EventHotKeyRef?

  private init() {
    brightnessKeys = UserDefaults.standard.object(forKey: "brightnessKeys") as? Bool ?? true
  }

  /// Made-up keys for drawing the menu (Tools/render-menu). Never started.
  init(preview needsPermission: Bool) {
    brightnessKeys = true
    self.needsPermission = needsPermission
  }

  func start() {
    registerShortcut()
    update()
  }

  // MARK: Brightness keys

  private func update() {
    stopTap()
    permissionTimer?.invalidate(); permissionTimer = nil
    needsPermission = false
    guard brightnessKeys else { return }
    if AXIsProcessTrusted() { startTap(); return }
    needsPermission = true
    // Notice the switch being turned on without a restart; stop asking once it is.
    let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
      guard AXIsProcessTrusted() else { return }
      self?.update()
    }
    timer.tolerance = 1
    RunLoop.main.add(timer, forMode: .common)
    permissionTimer = timer
  }

  func askForPermission() {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    if !AXIsProcessTrustedWithOptions([key: true] as CFDictionary) {
      NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
  }

  private func startTap() {
    let mask = CGEventMask(1 << 14) // NSSystemDefined: media and brightness keys
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                      eventsOfInterest: mask, callback: { _, type, event, _ in
                                        Keys.shared.handle(type, event)
                                      }, userInfo: nil) else {
      needsPermission = true
      return
    }
    self.tap = tap
    source = CFMachPortCreateRunLoopSource(nil, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  private func stopTap() {
    if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    tap = nil; source = nil
  }

  private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)
    }
    guard let ns = NSEvent(cgEvent: event), ns.type == .systemDefined, ns.subtype.rawValue == 8 else {
      return Unmanaged.passUnretained(event)
    }
    let key = (ns.data1 & 0xFFFF_0000) >> 16
    let down = ((ns.data1 & 0xFF00) >> 8) == 0xA
    let up = key == Int(NX_KEYTYPE_BRIGHTNESS_UP), dn = key == Int(NX_KEYTYPE_BRIGHTNESS_DOWN)
    guard up || dn else { return Unmanaged.passUnretained(event) }

    // The MacBook screen (and Apple displays) already respond to these keys: leave them to macOS.
    let screens = Screens.shared
    guard let target = screens.screenUnderPointer(), target.control != .apple, !target.isOff else {
      return Unmanaged.passUnretained(event)
    }
    if down {
      // Like macOS: 16 steps, or 64 finer steps with Option + Shift held.
      let fine = ns.modifierFlags.contains([.option, .shift])
      let step = fine ? 1.0 / 64 : 1.0 / 16
      let next = ((target.brightness / step).rounded() + (up ? 1 : -1)) * step
      DispatchQueue.main.async { screens.setBrightness(target, next, showIndicator: true) }
    }
    return nil
  }

  // MARK: Shortcut: ⌃⌥⌘C draws or opens the curtain

  static let shortcutLabel = "⌃⌥⌘C"

  private func registerShortcut() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
      DispatchQueue.main.async { Screens.shared.toggleAll() }
      return noErr
    }, 1, &spec, nil, nil)
    let id = EventHotKeyID(signature: OSType(0x4352_544E), id: 1) // "CRTN"
    RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(controlKey | optionKey | cmdKey), id,
                        GetApplicationEventTarget(), 0, &hotKey)
  }
}

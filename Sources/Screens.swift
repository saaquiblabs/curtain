// Every screen Curtain knows about: its brightness, and whether its curtain is drawn.

import AppKit
import CoreGraphics
import ServiceManagement

final class Screen: ObservableObject, Identifiable {
  enum Control { case apple, ddc, software }

  let id: CGDirectDisplayID
  let uuid: String
  let name: String
  let isBuiltin: Bool
  @Published fileprivate(set) var control: Control
  fileprivate let ddc: CFTypeRef?
  fileprivate var ddcMax: UInt16 = 100
  /// The monitor's DDC brightness when Curtain found it, and whether a write has been seen to land.
  fileprivate var ddcAtLaunch: UInt16?
  fileprivate var ddcVerified = false
  /// The screen's own calibrated colour curve (from its ColorSync profile). Software dimming
  /// scales this curve, so colours stay true; writing a plain curve shifted them blue.
  fileprivate var calibration: (red: [CGGammaValue], green: [CGGammaValue], blue: [CGGammaValue], count: UInt32)?

  @Published var brightness: Double = 1
  @Published var curtained = false

  fileprivate init(id: CGDirectDisplayID, uuid: String, name: String, isBuiltin: Bool, control: Control, ddc: CFTypeRef?) {
    self.id = id; self.uuid = uuid; self.name = name; self.isBuiltin = isBuiltin; self.control = control; self.ddc = ddc
  }

  /// Software dimming can't go to zero or the screen looks switched off without being off.
  var minimum: Double { control == .software ? 0.15 : 0 }
}

final class Screens: ObservableObject {
  static let shared = Screens()

  @Published private(set) var all: [Screen] = []
  @Published var notice: String?

  @Published var followMac: Bool { didSet { defaults.set(followMac, forKey: "followMac"); updateFollowTimer() } }
  @Published var openAtLogin: Bool {
    didSet {
      guard openAtLogin != (SMAppService.mainApp.status == .enabled) else { return }
      do { try openAtLogin ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() } catch {
        notice = "Couldn't change Open at Login: \(error.localizedDescription)"
      }
    }
  }

  private let defaults = UserDefaults.standard
  private let ddcQueue = DispatchQueue(label: "curtain.ddc", qos: .userInitiated)
  private var pendingDDC: [CGDirectDisplayID: UInt16] = [:]
  private var followTimer: Timer?
  private var lastMacBrightness: Float = -1
  private var refreshScheduled = false

  /// Curtained screens (UUID → display ID), so they survive sleep and restarts. Cleared by Quit.
  private var curtained: [String: Int] {
    get { defaults.dictionary(forKey: "curtained") as? [String: Int] ?? [:] }
    set { defaults.set(newValue, forKey: "curtained") }
  }
  /// Screens that are off right now. macOS forgets them while they're off, so we keep them here.
  private var offScreens: [CGDirectDisplayID: Screen] = [:]

  private init() {
    followMac = defaults.bool(forKey: "followMac")
    openAtLogin = SMAppService.mainApp.status == .enabled
  }

  func start() {
    // A screen left off by a crash isn't listed by macOS any more: switch it on so it shows up,
    // and refresh() draws its curtain again.
    let online = Self.list(CGGetOnlineDisplayList)
    for id in curtained.values.map(CGDirectDisplayID.init) where !online.contains(id) { _ = Self.configure(id, enabled: true) }
    refresh()
    CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
      guard !flags.contains(.beginConfigurationFlag) else { return }
      DispatchQueue.main.async { Screens.shared.scheduleRefresh() }
    }, nil)
    // macOS reports a screen going off, but not always one coming back on (after wake or unlock
    // it can quietly switch a curtained screen back on), so check again at each of those moments.
    let later = { (_: Notification) in DispatchQueue.main.asyncAfter(deadline: .now() + 2) { Screens.shared.refresh() } }
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
      workspace.addObserver(forName: name, object: nil, queue: .main, using: later)
    }
    DistributedNotificationCenter.default().addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main, using: later)
    NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
      Screens.shared.scheduleRefresh()
    }
    updateFollowTimer()
  }

  // MARK: Discovering screens

  private func scheduleRefresh() {
    guard !refreshScheduled else { return }
    refreshScheduled = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.refreshScheduled = false; self.refresh() }
  }

  func refresh() {
    let online = Self.list(CGGetOnlineDisplayList).filter { CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }
    for id in online { offScreens[id] = nil } // macOS turned it back on; enforceCurtains decides
    let existing = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let ddc = DDC.services(for: online.filter { CGDisplayIsBuiltin($0) == 0 && existing[$0] == nil })
    var screens: [Screen] = []
    for id in online {
      if let screen = existing[id] {
        // Display changes can reset colour curves: put software dimming back.
        if screen.control == .software { applySoftware(screen) }
        screen.curtained = false
        screens.append(screen)
      } else {
        screens.append(makeScreen(id, ddc: ddc[id]))
      }
    }
    for (id, screen) in offScreens where !online.contains(id) { screen.curtained = true; screens.append(screen) }
    all = screens.sorted { ($0.isBuiltin ? 0 : 1, $0.id) < ($1.isBuiltin ? 0 : 1, $1.id) }
    enforceCurtains()
  }

  private func makeScreen(_ id: CGDirectDisplayID, ddc: CFTypeRef?) -> Screen {
    let builtin = CGDisplayIsBuiltin(id) != 0
    // Only Apple-made screens: macOS 27 also "accepts" brightness for other monitors, but the
    // monitor itself never changes, so those go over DDC.
    let apple = builtin || (CGDisplayVendorNumber(id) == 1552 && (Private.canChangeBrightness?(id) ?? false))
    let ignoresDDC = defaults.bool(forKey: "ddcIgnored.\(Self.uuid(id))")
    let control: Screen.Control = apple ? .apple : (ddc != nil && !ignoresDDC ? .ddc : .software)
    let screen = Screen(id: id, uuid: Self.uuid(id), name: Self.name(id), isBuiltin: builtin, control: control, ddc: ddc)
    switch control {
    case .apple:
      var value: Float = 1
      _ = Private.getBrightness?(id, &value)
      screen.brightness = Double(value)
    case .ddc:
      screen.brightness = defaults.object(forKey: "brightness.\(screen.uuid)") as? Double ?? 1
      ddcQueue.async { [weak screen] in
        guard let screen, let service = screen.ddc, let read = DDC.read(service, command: DDC.brightness) else { return }
        DispatchQueue.main.async {
          screen.ddcMax = read.max
          screen.ddcAtLaunch = read.current
          screen.brightness = Double(read.current) / Double(read.max)
        }
      }
    case .software:
      screen.brightness = defaults.object(forKey: "brightness.\(screen.uuid)") as? Double ?? 1
      applySoftware(screen)
    }
    return screen
  }

  // MARK: Brightness

  func setBrightness(_ screen: Screen, _ value: Double, showIndicator: Bool = false) {
    let value = min(1, max(screen.minimum, value))
    screen.brightness = value
    switch screen.control {
    case .apple:
      _ = Private.setBrightness?(screen.id, Float(value))
    case .ddc:
      queueDDC(screen, UInt16((value * Double(screen.ddcMax)).rounded()))
      defaults.set(value, forKey: "brightness.\(screen.uuid)")
    case .software:
      applySoftware(screen)
      defaults.set(value, forKey: "brightness.\(screen.uuid)")
    }
    if showIndicator { OSD.showBrightness(value, on: screen.id) }
  }

  /// Slider drags fire far faster than a monitor can take DDC writes, so only the newest value
  /// waiting for each screen is sent.
  private func queueDDC(_ screen: Screen, _ raw: UInt16) {
    guard let service = screen.ddc else { return }
    let id = screen.id
    let alreadyQueued = pendingDDC[id] != nil
    pendingDDC[id] = raw
    guard !alreadyQueued else { return }
    ddcQueue.async { [weak self, weak screen] in
      var latest: UInt16?
      DispatchQueue.main.sync { latest = self?.pendingDDC[id] }
      while let value = latest {
        DDC.write(service, command: DDC.brightness, value: value)
        var check = false
        DispatchQueue.main.sync { check = screen.map { !$0.ddcVerified && $0.ddcAtLaunch != nil && $0.ddcAtLaunch != value } ?? false }
        if check, let screen { self?.verifyDDC(screen, service: service, expected: value) }
        DispatchQueue.main.sync {
          if self?.pendingDDC[id] == value { self?.pendingDDC[id] = nil; latest = nil } else { latest = self?.pendingDDC[id] }
          if screen?.control != .ddc { self?.pendingDDC[id] = nil; latest = nil }
        }
      }
    }
  }

  /// Some monitors (and many hubs and adapters) answer DDC reads but ignore writes. The first
  /// real change is read back once; if it didn't land, this monitor is dimmed in software from
  /// now on.
  private func verifyDDC(_ screen: Screen, service: CFTypeRef, expected: UInt16) {
    usleep(300_000)
    guard let read = DDC.read(service, command: DDC.brightness) else { return }
    DispatchQueue.main.sync {
      if read.current == expected { screen.ddcVerified = true; return }
      screen.control = .software
      defaults.set(true, forKey: "ddcIgnored.\(screen.uuid)")
      setBrightness(screen, screen.brightness)
      notice = "\(screen.name) ignores brightness commands, so Curtain dims it in software instead."
    }
  }

  // Ported from MonitorControl's Display.swift (MIT, see NOTICE): scale the default gamma table.
  private func applySoftware(_ screen: Screen) {
    if screen.calibration == nil {
      var r = [CGGammaValue](repeating: 0, count: 256), g = r, b = r
      var count: UInt32 = 0
      guard CGGetDisplayTransferByTable(screen.id, 256, &r, &g, &b, &count) == .success, count > 0 else { return }
      screen.calibration = (r, g, b, count)
    }
    guard let c = screen.calibration else { return }
    let v = CGGammaValue(screen.brightness)
    CGSetDisplayTransferByTable(screen.id, c.count, c.red.map { $0 * v }, c.green.map { $0 * v }, c.blue.map { $0 * v })
  }

  /// The screen the pointer is on: what the brightness keys change.
  func screenUnderPointer() -> Screen? {
    let point = NSEvent.mouseLocation
    guard let ns = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }),
          let id = ns.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
    return all.first { $0.id == id }
  }

  // MARK: Follow the Mac

  private func updateFollowTimer() {
    followTimer?.invalidate(); followTimer = nil
    guard followMac, all.contains(where: \.isBuiltin) else { return }
    lastMacBrightness = -1
    let timer = Timer(timeInterval: 1, repeats: true) { _ in Screens.shared.followTick() }
    timer.tolerance = 0.5
    RunLoop.main.add(timer, forMode: .common)
    followTimer = timer
  }

  private func followTick() {
    guard let builtin = all.first(where: { $0.isBuiltin && !$0.curtained }) else { return }
    var value: Float = 0
    guard Private.getBrightness?(builtin.id, &value) == 0, abs(value - lastMacBrightness) > 0.004 else { return }
    lastMacBrightness = value
    builtin.brightness = Double(value)
    for screen in all where !screen.isBuiltin && !screen.curtained { setBrightness(screen, Double(value)) }
  }

  // MARK: Curtain

  /// Draws (closed = true) or opens a screen's curtain. Returns a message if it can't.
  @discardableResult
  func setCurtain(_ screen: Screen, closed: Bool) -> Bool {
    notice = nil
    if closed {
      guard screensStillOn(excluding: [screen.id]) > 0 else {
        notice = "One screen has to stay on. Plug in or open another screen first."
        return false
      }
      guard Self.configure(screen.id, enabled: false) else {
        notice = "macOS didn't let Curtain switch off \(screen.name)."
        return false
      }
      offScreens[screen.id] = screen
      curtained[screen.uuid] = Int(screen.id)
    } else {
      curtained[screen.uuid] = nil
      offScreens[screen.id] = nil
      _ = Self.configure(screen.id, enabled: true)
    }
    screen.curtained = closed
    scheduleRefresh()
    return true
  }

  /// The keyboard shortcut: open every curtain if any is drawn, otherwise draw every curtain
  /// except on the screen you're working on.
  func toggleAll() {
    if all.contains(where: \.curtained) {
      openAll()
    } else {
      let keep = screenUnderPointer() ?? all.first { $0.isBuiltin } ?? all.first
      for screen in all where screen.id != keep?.id { setCurtain(screen, closed: true) }
    }
  }

  func openAll() {
    for screen in all where screen.curtained { setCurtain(screen, closed: false) }
  }

  /// Keeps curtains drawn when macOS turns a screen back on (wake, unlock, replug), and opens
  /// them all if nothing else is left on, such as when the MacBook lid closes.
  private func enforceCurtains() {
    let wanted = Set(curtained.keys)
    let on = all.filter { !$0.curtained }
    if on.isEmpty {
      if !offScreens.isEmpty { openAll() }
      return
    }
    // Only re-draw curtains if some other screen stays on, so you're never left in the dark.
    guard on.contains(where: { !wanted.contains($0.uuid) }) else { return }
    for screen in on where wanted.contains(screen.uuid) { setCurtain(screen, closed: true) }
  }

  private func screensStillOn(excluding ids: Set<CGDirectDisplayID>) -> Int {
    Self.list(CGGetActiveDisplayList).filter { !ids.contains($0) && offScreens[$0] == nil }.count
  }

  /// Every screen back on and colours back to normal. `forget` also clears the remembered
  /// curtains (Quit); without it they're drawn again next launch (logout, restart).
  func restoreEverything(forget: Bool) {
    if forget { curtained = [:] }
    for id in offScreens.keys { _ = Self.configure(id, enabled: true) }
    offScreens = [:]
    CGDisplayRestoreColorSyncSettings()
  }

  // MARK: Helpers

  private static func configure(_ id: CGDirectDisplayID, enabled: Bool) -> Bool {
    guard let fn = Private.configureDisplayEnabled else { return false }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else { return false }
    guard fn(config, id, enabled) == .success else { CGCancelDisplayConfiguration(config); return false }
    return CGCompleteDisplayConfiguration(config, .permanently) == .success
  }

  private static func list(_ fn: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError) -> [CGDirectDisplayID] {
    var ids = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    _ = fn(16, &ids, &count)
    return Array(ids.prefix(Int(count)))
  }

  private static func uuid(_ id: CGDirectDisplayID) -> String {
    guard let ref = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return "display-\(id)" }
    return CFUUIDCreateString(nil, ref) as String
  }

  private static func name(_ id: CGDirectDisplayID) -> String {
    if CGDisplayIsBuiltin(id) != 0 { return "MacBook screen" }
    if let ns = NSScreen.screens.first(where: { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == id }) {
      return ns.localizedName
    }
    if let info = Private.displayCreateInfoDictionary?(id)?.takeRetainedValue() as NSDictionary?,
       let names = info["DisplayProductName"] as? [String: String], let name = names["en_US"] ?? names.first?.value {
      return name
    }
    return "Display"
  }
}

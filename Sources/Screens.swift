// Every screen Curtain knows about: its brightness, and whether it's off.
//
// Two ways to switch a screen off:
// - Quick off (blackedOut): the screen fades to black in a quarter of a second, a black cover
//   blocks clicks, and the backlight goes down. Instant, no flash; windows stay where they are.
// - Unplug (curtained): macOS treats the screen as unplugged, so windows move to another screen
//   and the monitor sleeps. macOS blanks every screen for a moment while it rearranges them;
//   Curtain fades out first and back in after, so it reads as a fade rather than a glitch.

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
  /// Unplugged: macOS treats it as disconnected.
  @Published var curtained = false
  /// Quick off: black and covered, still connected.
  @Published var blackedOut = false
  var isOff: Bool { curtained || blackedOut }

  fileprivate init(id: CGDirectDisplayID, uuid: String, name: String, isBuiltin: Bool, control: Control, ddc: CFTypeRef?) {
    self.id = id; self.uuid = uuid; self.name = name; self.isBuiltin = isBuiltin; self.control = control; self.ddc = ddc
  }

  private static var previews: UInt32 = 0

  /// A made-up screen for drawing the menu (Tools/render-menu). Not connected to any display.
  static func preview(name: String, isBuiltin: Bool, control: Control, brightness: Double,
                      blackedOut: Bool = false, curtained: Bool = false) -> Screen {
    previews += 1
    let screen = Screen(id: CGDirectDisplayID(0xC0DE_0000 + previews), uuid: "preview-\(previews)", name: name,
                        isBuiltin: isBuiltin, control: control, ddc: nil)
    screen.brightness = brightness
    screen.blackedOut = blackedOut
    screen.curtained = curtained
    return screen
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

  /// Unplugged screens (UUID → display ID): kept unplugged through sleep and unlock, and
  /// plugged back in at the next launch if Curtain didn't get to do it on the way out.
  private var curtained: [String: Int] {
    get { defaults.dictionary(forKey: "curtained") as? [String: Int] ?? [:] }
    set { defaults.set(newValue, forKey: "curtained") }
  }
  /// Screens that are off right now. macOS forgets them while they're off, so we keep them here.
  private var offScreens: [CGDirectDisplayID: Screen] = [:]
  /// Black windows covering quick-off screens, and running gamma fades.
  private var covers: [CGDirectDisplayID: NSWindow] = [:]
  private var fades: [CGDirectDisplayID: Timer] = [:]

  private init() {
    followMac = defaults.bool(forKey: "followMac")
    openAtLogin = SMAppService.mainApp.status == .enabled
  }

  /// A made-up set of screens for drawing the menu (Tools/render-menu). Never started, so it
  /// doesn't read, dim or rearrange any real display.
  init(preview screens: [Screen]) {
    followMac = false
    openAtLogin = false
    all = screens
  }

  func start() {
    // Every launch starts with all screens on. A screen left unplugged by a crash or force quit
    // isn't listed by macOS any more, so plug it back in by its remembered ID.
    let online = Self.list(CGGetOnlineDisplayList)
    let lost = curtained.values.map(CGDirectDisplayID.init).filter { !online.contains($0) }
    if !lost.isEmpty { _ = Self.configure(lost, enabled: true) }
    curtained = [:]
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
        screen.curtained = false
        // Display changes can reset colour curves and move screens: put dimming and covers back.
        if fades[id] == nil { applyGamma(screen) }
        if screen.blackedOut { showCover(screen) }
        screens.append(screen)
      } else {
        screens.append(makeScreen(id, ddc: ddc[id]))
      }
    }
    for (id, screen) in offScreens where !online.contains(id) { screen.curtained = true; screens.append(screen) }
    all = screens.sorted { ($0.isBuiltin ? 0 : 1, $0.id) < ($1.isBuiltin ? 0 : 1, $1.id) }
    for id in covers.keys where !online.contains(id) { hideCover(id) }
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
      applyGamma(screen)
    }
    return screen
  }

  // MARK: Brightness

  func setBrightness(_ screen: Screen, _ value: Double, showIndicator: Bool = false) {
    let value = min(1, max(screen.minimum, value))
    screen.brightness = value
    guard !screen.blackedOut else { return } // applied when it's turned back on
    switch screen.control {
    case .apple:
      _ = Private.setBrightness?(screen.id, Float(value))
    case .ddc:
      queueDDC(screen, UInt16((value * Double(screen.ddcMax)).rounded()))
      defaults.set(value, forKey: "brightness.\(screen.uuid)")
    case .software:
      applyGamma(screen)
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

  // MARK: Colour curves
  // Ported from MonitorControl's Display.swift (MIT, see NOTICE): scale the default gamma table.

  /// How bright the colour curve should be: 0 when off, the slider for software dimming, else 1.
  private func gammaScale(_ screen: Screen) -> CGGammaValue {
    screen.blackedOut ? 0 : (screen.control == .software ? CGGammaValue(screen.brightness) : 1)
  }

  private func applyGamma(_ screen: Screen, scale: CGGammaValue? = nil) {
    if screen.calibration == nil {
      // Captured before Curtain ever changes the curve, so this is the true calibration.
      var r = [CGGammaValue](repeating: 0, count: 256), g = r, b = r
      var count: UInt32 = 0
      guard CGGetDisplayTransferByTable(screen.id, 256, &r, &g, &b, &count) == .success, count > 0 else { return }
      screen.calibration = (r, g, b, count)
    }
    guard let c = screen.calibration else { return }
    let v = scale ?? gammaScale(screen)
    if v == 1, screen.control != .software, scale == nil {
      CGSetDisplayTransferByTable(screen.id, c.count, c.red, c.green, c.blue)
    } else {
      CGSetDisplayTransferByTable(screen.id, c.count, c.red.map { $0 * v }, c.green.map { $0 * v }, c.blue.map { $0 * v })
    }
  }

  /// Eases the colour curve from one brightness to another, about as fast as macOS's own fades.
  private func fadeGamma(_ screen: Screen, from: CGGammaValue, to: CGGammaValue, duration: Double, done: (() -> Void)? = nil) {
    fades[screen.id]?.invalidate()
    let start = Date()
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
      let p = min(1, Date().timeIntervalSince(start) / duration)
      let eased = p * p * (3 - 2 * p)
      self?.applyGamma(screen, scale: from + (to - from) * CGGammaValue(eased))
      guard p >= 1 else { return }
      timer.invalidate()
      self?.fades[screen.id] = nil
      done?()
    }
    RunLoop.main.add(timer, forMode: .common)
    fades[screen.id] = timer
  }

  /// The screen the pointer is on: what the brightness keys change.
  func screenUnderPointer() -> Screen? {
    let point = NSEvent.mouseLocation
    guard let id = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) })?.displayID else { return nil }
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
    guard let builtin = all.first(where: { $0.isBuiltin && !$0.isOff }) else { return }
    var value: Float = 0
    guard Private.getBrightness?(builtin.id, &value) == 0, abs(value - lastMacBrightness) > 0.004 else { return }
    lastMacBrightness = value
    builtin.brightness = Double(value)
    for screen in all where !screen.isBuiltin && !screen.isOff { setBrightness(screen, Double(value)) }
  }

  // MARK: Quick off

  /// Fades a screen to black (off = true) or back (off = false). Returns false if it can't.
  @discardableResult
  func setQuickOff(_ screen: Screen, off: Bool) -> Bool {
    notice = nil
    if off {
      guard !screen.isOff else { return true }
      guard screensVisible(excluding: screen.id) > 0 else {
        notice = "One screen has to stay on. Turn another screen on first."
        return false
      }
      let from = gammaScale(screen)
      screen.blackedOut = true
      fadeGamma(screen, from: from, to: 0, duration: 0.25) { [weak self, weak screen] in
        guard let self, let screen, screen.blackedOut else { return }
        self.showCover(screen)
        self.setBacklight(screen, 0)
      }
    } else {
      guard screen.blackedOut else { return true }
      screen.blackedOut = false
      hideCover(screen.id)
      setBacklight(screen, screen.brightness)
      fadeGamma(screen, from: 0, to: gammaScale(screen), duration: 0.35) { [weak self, weak screen] in
        if let screen { self?.applyGamma(screen) }
      }
    }
    all = all // republish so the menu bar icon updates
    return true
  }

  /// Whether Turn off is allowed: some other screen has to stay on, so you're never left in the dark.
  func canTurnOff(_ screen: Screen) -> Bool {
    all.contains { $0.id != screen.id && !$0.isOff }
  }

  /// The backlight follows quick off where Curtain can reach it: MacBook and Apple screens, and
  /// monitors that take DDC. The black curve and cover do the rest.
  private func setBacklight(_ screen: Screen, _ value: Double) {
    switch screen.control {
    case .apple: _ = Private.setBrightness?(screen.id, Float(value))
    case .ddc: queueDDC(screen, UInt16((value * Double(screen.ddcMax)).rounded()))
    case .software: break
    }
  }

  private func showCover(_ screen: Screen) {
    guard let ns = Self.nsScreen(screen.id) else { return }
    let window = covers[screen.id] ?? {
      let w = NSWindow(contentRect: ns.frame, styleMask: .borderless, backing: .buffered, defer: false)
      w.backgroundColor = .black
      w.isOpaque = true
      w.hasShadow = false
      w.isReleasedWhenClosed = false
      w.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
      w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
      return w
    }()
    window.setFrame(ns.frame, display: true)
    window.orderFrontRegardless()
    covers[screen.id] = window
  }

  private func hideCover(_ id: CGDirectDisplayID) {
    covers[id]?.orderOut(nil)
    covers[id] = nil
  }

  // MARK: Unplug

  /// Unplugs (closed = true) or plugs back in a screen. Returns false if it can't.
  @discardableResult
  func setCurtain(_ screen: Screen, closed: Bool) -> Bool {
    notice = nil
    if closed {
      guard !screen.curtained else { return true }
      // Unplugging the built-in screen makes macOS act as if the lid were closed: the built-in
      // keyboard and trackpad stop working. Turn off is the safe way to darken it.
      guard !screen.isBuiltin else {
        notice = "The MacBook screen can't be unplugged: macOS would switch off its keyboard and trackpad. Use Turn off."
        return false
      }
      guard screensVisible(excluding: screen.id) > 0 else {
        notice = "One screen has to stay on. Turn another screen on first."
        return false
      }
      if screen.blackedOut { // switching from quick off: drop the cover quietly
        screen.blackedOut = false
        hideCover(screen.id)
        setBacklight(screen, screen.brightness)
      }
      guard Self.withFade({ Self.configure([screen.id], enabled: false) }) else {
        notice = "macOS didn't let Curtain unplug \(screen.name)."
        return false
      }
      offScreens[screen.id] = screen
      curtained[screen.uuid] = Int(screen.id)
    } else {
      guard screen.curtained else { return true }
      curtained[screen.uuid] = nil
      offScreens[screen.id] = nil
      _ = Self.withFade { Self.configure([screen.id], enabled: true) }
    }
    screen.curtained = closed
    scheduleRefresh()
    return true
  }

  /// The keyboard shortcut: turn every screen back on if any is off, otherwise quick-off every
  /// screen except the one you're working on.
  func toggleAll() {
    if all.contains(where: \.isOff) {
      openAll()
    } else {
      let keep = screenUnderPointer() ?? all.first { $0.isBuiltin } ?? all.first
      for screen in all where screen.id != keep?.id { setQuickOff(screen, off: true) }
    }
  }

  func openAll() {
    for screen in all where screen.blackedOut { setQuickOff(screen, off: false) }
    let unplugged = all.filter(\.curtained)
    guard !unplugged.isEmpty else { return }
    for screen in unplugged {
      curtained[screen.uuid] = nil
      offScreens[screen.id] = nil
      screen.curtained = false
    }
    _ = Self.withFade { Self.configure(unplugged.map(\.id), enabled: true) } // one fade for all
    scheduleRefresh()
  }

  /// Keeps screens unplugged when macOS plugs them back in (wake, unlock, replug), and plugs them
  /// all back in if nothing else is left on, such as when the MacBook lid closes.
  private func enforceCurtains() {
    let wanted = Set(curtained.keys)
    let on = all.filter { !$0.curtained }
    if on.isEmpty {
      if !offScreens.isEmpty { openAll() }
      return
    }
    // Only unplug again if some other screen stays on, so you're never left in the dark.
    guard on.contains(where: { !wanted.contains($0.uuid) && !$0.blackedOut }) else { return }
    for screen in on where wanted.contains(screen.uuid) { setCurtain(screen, closed: true) }
  }

  /// Screens you can still see: connected and not quick-off.
  private func screensVisible(excluding id: CGDirectDisplayID) -> Int {
    Self.list(CGGetActiveDisplayList).filter { other in
      other != id && offScreens[other] == nil && !(all.first { $0.id == other }?.blackedOut ?? false)
    }.count
  }

  /// Every screen back on, backlights and colours back to normal.
  func restoreEverything() {
    for timer in fades.values { timer.invalidate() }
    fades = [:]
    for screen in all where screen.blackedOut {
      screen.blackedOut = false
      hideCover(screen.id)
      if screen.control == .apple { _ = Private.setBrightness?(screen.id, Float(screen.brightness)) }
      if screen.control == .ddc, let service = screen.ddc {
        DDC.write(service, command: DDC.brightness, value: UInt16((screen.brightness * Double(screen.ddcMax)).rounded()))
      }
    }
    curtained = [:]
    if !offScreens.isEmpty { _ = Self.configure(Array(offScreens.keys), enabled: true) }
    offScreens = [:]
    CGDisplayRestoreColorSyncSettings()
  }

  // MARK: Helpers

  /// Fades every screen to black, runs `change`, holds black while monitors re-sync, then fades
  /// back in without blocking the app.
  private static func withFade(_ change: () -> Bool) -> Bool {
    var token: CGDisplayFadeReservationToken = 0
    guard CGAcquireDisplayFadeReservation(5, &token) == .success else { return change() }
    let normal = CGDisplayBlendFraction(kCGDisplayBlendNormal), black = CGDisplayBlendFraction(kCGDisplayBlendSolidColor)
    CGDisplayFade(token, 0.3, normal, black, 0, 0, 0, 1)
    let ok = change()
    DispatchQueue.global(qos: .userInteractive).async {
      usleep(1_200_000)
      CGDisplayFade(token, 0.5, black, normal, 0, 0, 0, 1)
      CGReleaseDisplayFadeReservation(token)
      DispatchQueue.main.async { Screens.shared.refresh() } // the fade restores curves; re-dim
    }
    return ok
  }

  private static func configure(_ ids: [CGDirectDisplayID], enabled: Bool) -> Bool {
    guard let fn = Private.configureDisplayEnabled else { return false }
    var config: CGDisplayConfigRef?
    guard CGBeginDisplayConfiguration(&config) == .success else { return false }
    for id in ids where fn(config, id, enabled) != .success {
      CGCancelDisplayConfiguration(config)
      return false
    }
    // For this session only: `.permanently` rewrote macOS's saved display arrangement, which can
    // change scaling and colour settings later.
    return CGCompleteDisplayConfiguration(config, .forSession) == .success
  }

  static func nsScreen(_ id: CGDirectDisplayID) -> NSScreen? {
    NSScreen.screens.first { $0.displayID == id }
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
    if CGDisplayIsBuiltin(id) != 0 { return "MacBook" }
    if let ns = nsScreen(id) {
      return ns.localizedName
    }
    if let info = Private.displayCreateInfoDictionary?(id)?.takeRetainedValue() as NSDictionary?,
       let names = info["DisplayProductName"] as? [String: String], let name = names["en_US"] ?? names.first?.value {
      return name
    }
    return "Display"
  }
}

extension NSScreen {
  /// The Core Graphics display this screen shows.
  var displayID: CGDirectDisplayID? { deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
}

// What a tile on the desk map shows while a control is under the pointer (#26): the control's
// result, half done, on the tile only, never on a real screen. Plain logic, tested in `make test`.

enum TilePreview {
  /// What the control under the pointer would do.
  enum Preview: Equatable { case turnOff, turnOn, disconnect, reconnect, brightness(Double), quit }

  /// How the tile is drawn. `closed`: the drapes, 0 open to 1 closed. `shown`: the monitor, 1
  /// drawn to 0 only its dashed outline. `brightness`: its glow.
  struct Look: Equatable {
    var closed: Double
    var shown: Double
    var brightness: Double
  }

  /// A preview goes halfway, so it never looks like the real thing.
  static let half = 0.5

  /// `aimed`: the control belongs to this tile's screen. Quit reaches every tile. A disabled
  /// control passes no preview.
  static func look(off: Bool, disconnected: Bool, brightness: Double, preview: Preview?, aimed: Bool) -> Look {
    var look = Look(closed: off ? 1 : 0, shown: disconnected ? 0 : 1, brightness: brightness)
    guard let preview, aimed || preview == .quit else { return look }
    switch preview {
    case .turnOff where !off && !disconnected: look.closed = half
    case .turnOn where off: look.closed = half
    case .disconnect where !disconnected: look.shown = half
    case .reconnect where disconnected: look.shown = half
    case .brightness(let value) where !off && !disconnected: look.brightness = value
    case .quit:
      if off { look.closed = half }
      if disconnected { look.shown = half }
    default: break
    }
    return look
  }
}

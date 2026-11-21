// DDC/CI on Apple silicon: reading and writing a monitor's own settings (brightness, power).
//
// Ported from MonitorControl's Arm64DDC.swift
// Copyright © MonitorControl. @JoniVR, @theOneyouseek, @waydabber and others. MIT, see NOTICE.
// Changes: trimmed to what Curtain uses, private functions looked up at run time (Private.swift),
// and the service matching returns a plain display-ID → service map.

import CoreGraphics
import Foundation
import IOKit

enum DDC {
  static let brightness: UInt8 = 0x10
  static let powerMode: UInt8 = 0xD6

  private static let chipAddress: UInt8 = 0x37
  private static let dataAddress: UInt8 = 0x51
  private static let maxMatchScore = 20

  static var available: Bool {
    #if arch(arm64)
      Private.avServiceWriteI2C != nil && Private.avServiceReadI2C != nil
    #else
      false
    #endif
  }

  // MARK: Read and write

  static func read(_ service: CFTypeRef, command: UInt8) -> (current: UInt16, max: UInt16)? {
    var send: [UInt8] = [command]
    var reply = [UInt8](repeating: 0, count: 11)
    guard communicate(service, send: &send, reply: &reply) else { return nil }
    let max = UInt16(reply[6]) << 8 | UInt16(reply[7])
    let current = UInt16(reply[8]) << 8 | UInt16(reply[9])
    return max == 0 ? nil : (current, max)
  }

  @discardableResult
  static func write(_ service: CFTypeRef, command: UInt8, value: UInt16) -> Bool {
    var send: [UInt8] = [command, UInt8(value >> 8), UInt8(value & 0xFF)]
    var reply: [UInt8] = []
    return communicate(service, send: &send, reply: &reply)
  }

  private static func communicate(_ service: CFTypeRef, send: inout [UInt8], reply: inout [UInt8],
                                  retries: Int = 4, writeCycles: Int = 2) -> Bool {
    guard let writeI2C = Private.avServiceWriteI2C, let readI2C = Private.avServiceReadI2C else { return false }
    var packet: [UInt8] = [UInt8(0x80 | (send.count + 1)), UInt8(send.count)] + send + [0]
    packet[packet.count - 1] = checksum(send.count == 1 ? chipAddress << 1 : chipAddress << 1 ^ dataAddress,
                                        packet, 0, packet.count - 2)
    var success = false
    for _ in 0 ... retries {
      for _ in 0 ..< max(writeCycles, 1) {
        usleep(10000)
        success = writeI2C(service, UInt32(chipAddress), UInt32(dataAddress), &packet, UInt32(packet.count)) == 0
      }
      if !reply.isEmpty {
        usleep(50000)
        if readI2C(service, UInt32(chipAddress), 0, &reply, UInt32(reply.count)) == 0 {
          success = checksum(0x50, reply, 0, reply.count - 2) == reply[reply.count - 1]
        }
      }
      if success { return true }
      usleep(20000)
    }
    return false
  }

  private static func checksum(_ start: UInt8, _ data: [UInt8], _ from: Int, _ to: Int) -> UInt8 {
    var value = start
    for i in from ... to { value ^= data[i] }
    return value
  }

  // MARK: Pairing displays with DDC channels

  private struct IORegService {
    var edidUUID = ""
    var productName = ""
    var serialNumber: Int64 = 0
    var ioDisplayLocation = ""
    var service: CFTypeRef?
    var serviceLocation = 0
  }

  /// Finds the DDC channel for each external display. Displays without one (AirPlay, DisplayLink,
  /// some docks) are left out, and Curtain dims those in software instead.
  static func services(for displayIDs: [CGDirectDisplayID]) -> [CGDirectDisplayID: CFTypeRef] {
    guard available else { return [:] }
    let candidates = ioregServices()
    var scored: [Int: [(CGDirectDisplayID, IORegService)]] = [:]
    for id in displayIDs {
      for candidate in candidates where candidate.service != nil {
        scored[matchScore(id, candidate), default: []].append((id, candidate))
      }
    }
    var result: [CGDirectDisplayID: CFTypeRef] = [:]
    var takenLocations = Set<Int>()
    for score in stride(from: maxMatchScore, to: 0, by: -1) {
      for (id, candidate) in scored[score] ?? []
        where result[id] == nil && !takenLocations.contains(candidate.serviceLocation) {
        result[id] = candidate.service
        takenLocations.insert(candidate.serviceLocation)
      }
    }
    return result
  }

  private static func matchScore(_ displayID: CGDirectDisplayID, _ s: IORegService) -> Int {
    guard let info = Private.displayCreateInfoDictionary?(displayID)?.takeRetainedValue() as NSDictionary? else { return 0 }
    var score = 0
    if let year = info["DisplayYearManufacture"] as? Int64, let week = info["DisplayWeekManufacture"] as? Int64,
       let vendor = info["DisplayVendorID"] as? Int64, let product = info["DisplayProductID"] as? Int64,
       let vSize = info["DisplayVerticalImageSize"] as? Int64, let hSize = info["DisplayHorizontalImageSize"] as? Int64 {
      func hex8(_ v: Int64) -> String { String(format: "%02X", UInt8(max(0, min(v, 255)))) }
      let p = UInt16(max(0, min(product, 65535)))
      let keys: [(String, Int)] = [
        (String(format: "%04X", UInt16(max(0, min(vendor, 65535)))), 0),
        (String(format: "%02X%02X", UInt8(p & 0xFF), UInt8(p >> 8)), 4),
        (hex8(week) + hex8(year - 1990), 19),
        (hex8(hSize / 10) + hex8(vSize / 10), 30),
      ]
      for (key, loc) in keys where key != "0000" && key == String(s.edidUUID.prefix(loc + 4).suffix(4)) {
        score += 1
      }
    }
    if !s.ioDisplayLocation.isEmpty, let location = info[kIODisplayLocationKey] as? String, location == s.ioDisplayLocation {
      score += 10
    }
    if !s.productName.isEmpty, let names = info["DisplayProductName"] as? [String: String],
       let name = names["en_US"] ?? names.first?.value, name.lowercased() == s.productName.lowercased() {
      score += 1
    }
    if s.serialNumber != 0, let serial = info[kDisplaySerialNumber] as? Int64, serial == s.serialNumber {
      score += 1
    }
    return score
  }

  private static func property(_ entry: io_service_t, _ key: String) -> Any? {
    IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault,
                                    IOOptionBits(kIORegistryIterateRecursively))?.takeRetainedValue()
  }

  private static func ioregServices() -> [IORegService] {
    var found: [IORegService] = []
    let root = IORegistryGetRootEntry(kIOMainPortDefault)
    defer { IOObjectRelease(root) }
    var iterator = io_iterator_t()
    guard IORegistryEntryCreateIterator(root, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
      return found
    }
    defer { IOObjectRelease(iterator) }
    let framebuffers = ["AppleCLCD2", "IOMobileFramebufferShim"]
    var current = IORegService()
    var location = 0
    let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer { name.deallocate() }
    while true {
      let entry = IOIteratorNext(iterator)
      guard entry != IO_OBJECT_NULL else { break }
      defer { IOObjectRelease(entry) }
      guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS else { continue }
      let entryName = String(cString: name)
      if framebuffers.contains(where: { entryName.contains($0) }) {
        current = IORegService()
        location += 1
        current.serviceLocation = location
        current.edidUUID = property(entry, "EDID UUID") as? String ?? ""
        let path = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
        IORegistryEntryGetPath(entry, kIOServicePlane, path)
        current.ioDisplayLocation = String(cString: path)
        path.deallocate()
        if let attrs = property(entry, "DisplayAttributes") as? NSDictionary,
           let product = attrs["ProductAttributes"] as? NSDictionary {
          current.productName = product["ProductName"] as? String ?? ""
          current.serialNumber = product["SerialNumber"] as? Int64 ?? 0
        }
      } else if entryName.contains("DCPAVServiceProxy") {
        if property(entry, "Location") as? String == "External",
           let create = Private.avServiceCreateWithService {
          current.service = create(kCFAllocatorDefault, entry)?.takeRetainedValue()
        }
        found.append(current)
      }
    }
    return found
  }
}

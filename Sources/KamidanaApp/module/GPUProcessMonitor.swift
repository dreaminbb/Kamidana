import AppKit
import Foundation
import IOKit

struct GPUProcessStat: Identifiable {
  let id: Int32
  let name: String
  let icon: NSImage?
  let gpuUsage: Double
}

final class GPUProcessMonitor {
  private var previousGPUTime: [Int32: UInt64] = [:]
  private var previousSampleDate: Date?
  private var processes: [GPUProcessStat] = []

  func update() {
    let now = Date()
    let accumulatedTimes = accumulatedGPUTimeByProcess()
    defer {
      previousGPUTime = accumulatedTimes.mapValues(\.time)
      previousSampleDate = now
    }

    guard let previousSampleDate else {
      processes = []
      return
    }

    let elapsedNanoseconds = now.timeIntervalSince(previousSampleDate) * 1_000_000_000
    guard elapsedNanoseconds > 0 else { return }

    processes = accumulatedTimes.compactMap { pid, entry in
      let previous = previousGPUTime[pid] ?? entry.time
      let delta = entry.time >= previous ? entry.time - previous : 0
      let usage = Double(delta) / elapsedNanoseconds * 100
      guard usage > 0 else { return nil }

      let application = NSRunningApplication(processIdentifier: pid_t(pid))
      return GPUProcessStat(
        id: pid,
        name: application?.localizedName ?? entry.name,
        icon: application?.icon,
        gpuUsage: usage
      )
    }
    .sorted { $0.gpuUsage > $1.gpuUsage }
  }

  func topProcesses(limit: Int) -> [GPUProcessStat] {
    Array(processes.prefix(limit))
  }

  static func processIdentifier(from creator: String) -> Int32? {
    let components = creator.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
    guard let identifier = components.first?.trimmingCharacters(in: .whitespaces).split(separator: " ").last,
          let pid = Int32(identifier) else { return nil }
    return pid
  }

  static func processName(from creator: String) -> String {
    let components = creator.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
    guard components.count == 2 else { return "Unknown" }
    let name = components[1].trimmingCharacters(in: .whitespaces)
    return name.isEmpty ? "Unknown" : name
  }

  static func accumulatedGPUTime(from appUsage: [[String: Any]]) -> UInt64 {
    appUsage.reduce(0) { total, item in
      total + ((item["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0)
    }
  }

  private func accumulatedGPUTimeByProcess() -> [Int32: (name: String, time: UInt64)] {
    var result: [Int32: (name: String, time: UInt64)] = [:]
    let matching = IOServiceMatching("IOAccelerator")
    var serviceIterator: io_iterator_t = 0
    guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &serviceIterator) == KERN_SUCCESS
    else { return result }
    defer { IOObjectRelease(serviceIterator) }

    var accelerator = IOIteratorNext(serviceIterator)
    while accelerator != 0 {
      let currentAccelerator = accelerator
      var clientIterator: io_iterator_t = 0
      if IORegistryEntryCreateIterator(
        currentAccelerator,
        kIOServicePlane,
        IOOptionBits(kIORegistryIterateRecursively),
        &clientIterator
      ) == KERN_SUCCESS {
        var client = IOIteratorNext(clientIterator)
        while client != 0 {
          let currentClient = client
          let creator = IORegistryEntryCreateCFProperty(
            currentClient,
            "IOUserClientCreator" as CFString,
            kCFAllocatorDefault,
            0
          )?.takeRetainedValue() as? String
          let appUsage = IORegistryEntryCreateCFProperty(
            currentClient,
            "AppUsage" as CFString,
            kCFAllocatorDefault,
            0
          )?.takeRetainedValue() as? [[String: Any]]

          if let creator,
             let pid = Self.processIdentifier(from: creator),
             let appUsage {
            let time = Self.accumulatedGPUTime(from: appUsage)
            if time > 0 {
              let current = result[pid]
              result[pid] = (
                name: Self.processName(from: creator),
                time: (current?.time ?? 0) + time
              )
            }
          }
          IOObjectRelease(currentClient)
          client = IOIteratorNext(clientIterator)
        }
        IOObjectRelease(clientIterator)
      }
      IOObjectRelease(currentAccelerator)
      accelerator = IOIteratorNext(serviceIterator)
    }
    return result
  }
}

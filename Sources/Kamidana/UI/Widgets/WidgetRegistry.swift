import SwiftUI

public protocol WidgetFactory {
  var typeID: String { get }
  func makeView(config: Any) -> AnyView
  func getTabName(config: Any) -> String
  func decodeConfiguration(from decoder: Decoder) throws -> AnyHashable
}

struct GenericWidgetFactory<C: Decodable & Hashable, V: View>: WidgetFactory {
  let typeID: String
  let viewMaker: (C) -> V
  let tabNameMaker: (C) -> String

  func makeView(config: Any) -> AnyView {
    guard let c = config as? C else { return AnyView(EmptyView()) }
    return AnyView(viewMaker(c))
  }

  func getTabName(config: Any) -> String {
    guard let c = config as? C else { return "Unknown" }
    return tabNameMaker(c)
  }

  func decodeConfiguration(from decoder: Decoder) throws -> AnyHashable {
    AnyHashable(try C(from: decoder))
  }
}

public class WidgetRegistry {
  public static let shared = WidgetRegistry()
  private var factories: [String: WidgetFactory] = [:]
  private var hasRegisteredBuiltIns = false

  private init() {}

  public func register(factory: WidgetFactory) {
    factories[factory.typeID] = factory
  }

  public func factory(for typeID: String) -> WidgetFactory? {
    return factories[typeID]
  }

  public func registerAllWidgets() {
    guard !hasRegisteredBuiltIns else { return }
    hasRegisteredBuiltIns = true

    register(
      factory: GenericWidgetFactory<SystemActionWidgetConfig, SystemActionWidget>(
        typeID: "systemAction",
        viewMaker: { config in SystemActionWidget(config: config) },
        tabNameMaker: { config in config.name ?? "System Action" }
      ))
    register(
      factory: GenericWidgetFactory<WifiWidgetConfig, WiFiWidget>(
        typeID: "wifi",
        viewMaker: { config in WiFiWidget(config: config) },
        tabNameMaker: { _ in "WiFi" }
      ))
    register(
      factory: GenericWidgetFactory<AudioWidgetConfig, AudioWidget>(
        typeID: "audio",
        viewMaker: { config in AudioWidget(config: config) },
        tabNameMaker: { _ in "Audio" }
      ))
    register(
      factory: GenericWidgetFactory<MusicWidgetConfig, MusicWidget>(
        typeID: "music",
        viewMaker: { config in MusicWidget(config: config) },
        tabNameMaker: { _ in "Music" }
      ))
    register(
      factory: GenericWidgetFactory<TerminalWidgetConfig, AnyView>(
        typeID: "terminal",
        viewMaker: { config in
          AnyView(TerminalView(executable: config.terminalPath).cornerRadius(12).padding(12))
        },
        tabNameMaker: { config in config.name }
      ))
    register(
      factory: GenericWidgetFactory<NetworkWidgetConfig, NetworkWidget>(
        typeID: "network",
        viewMaker: { config in NetworkWidget(config: config) },
        tabNameMaker: { _ in "Network" }
      ))
    register(
      factory: GenericWidgetFactory<CpuWidgetConfig, CpuWidget>(
        typeID: "cpu",
        viewMaker: { config in CpuWidget(config: config) },
        tabNameMaker: { _ in "CPU" }
      ))
    register(
      factory: GenericWidgetFactory<MemoryWidgetConfig, MemoryWidget>(
        typeID: "memory",
        viewMaker: { config in MemoryWidget(config: config) },
        tabNameMaker: { _ in "Memory" }
      ))
    register(
      factory: GenericWidgetFactory<DiskWidgetConfig, DiskWidget>(
        typeID: "disk",
        viewMaker: { config in DiskWidget(config: config) },
        tabNameMaker: { _ in "Disk" }
      ))
    register(
      factory: GenericWidgetFactory<BluetoothWidgetConfig, BluetoothWidget>(
        typeID: "bluetooth",
        viewMaker: { config in BluetoothWidget(config: config) },
        tabNameMaker: { _ in "Bluetooth" }
      ))
    register(
      factory: GenericWidgetFactory<BatteryWidgetConfig, BatteryWidget>(
        typeID: "battery",
        viewMaker: { config in BatteryWidget(config: config) },
        tabNameMaker: { _ in "Battery" }
      ))
    register(
      factory: GenericWidgetFactory<ClockWidgetConfig, ClockWidget>(
        typeID: "clock",
        viewMaker: { config in ClockWidget(config: config) },
        tabNameMaker: { _ in "Clock" }
      ))
    register(
      factory: GenericWidgetFactory<WidgetFolderConfig, WidgetFolder>(
        typeID: "widgetFolder",
        viewMaker: { config in WidgetFolder(config: config) },
        tabNameMaker: { _ in "Folder" }
      ))
    register(
      factory: GenericWidgetFactory<CustomWidgetConfig, CustomWidget>(
        typeID: "custom",
        viewMaker: { config in CustomWidget(config: config) },
        tabNameMaker: { _ in "Custom" }
      ))
    register(
      factory: GenericWidgetFactory<GpuWidgetConfig, GpuWidget>(
        typeID: "gpu",
        viewMaker: { config in GpuWidget(config: config) },
        tabNameMaker: { _ in "GPU" }
      ))
  }
}

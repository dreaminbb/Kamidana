import SwiftUI

public struct CustomWidgetConfig: Codable, Hashable {
  public var command: String
  public var arguments: [String]
  public var format: String?

  public init(
    command: String,
    arguments: [String] = [],
    format: String? = nil
  ) {
    self.command = command
    self.arguments = arguments
    self.format = format
  }
}

/// A v1 custom widget executes a process directly and never invokes a shell.
public struct CustomWidget: View {
  @Environment(\.kamidanaV1Style) private var v1Style
  @Environment(\.kamidanaWidgetFormat) private var widgetFormat
  public let config: CustomWidgetConfig
  @State private var output = ""
  @State private var isRunning = false

  public init(config: CustomWidgetConfig) {
    self.config = config
  }

  public var body: some View {
    Button(action: runProcess) {
      FormattedWidgetLabel(
        format: widgetFormat ?? config.format ?? "{output}",
        values: ["output": output.isEmpty ? config.command : output],
        iconColor: Color(hex: v1Style?.iconColor ?? "#cdd6f4"),
        textColor: Color(hex: v1Style?.color ?? "#cdd6f4")
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isRunning)
    .SmoothUIModule()
    .help(output)
  }

  private func runProcess() {
    let processConfig = config
    isRunning = true
    DispatchQueue.global(qos: .userInitiated).async {
      let result: String
      guard
        let executable = KamidanaExecutableResolver.resolve(processConfig.command)
          ?? (processConfig.command.hasPrefix("/") ? processConfig.command : nil)
      else {
        result = "Command not found: \(processConfig.command)"
        DispatchQueue.main.async {
          output = result
          isRunning = false
        }
        return
      }

      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = processConfig.arguments
      let pipe = Pipe()
      process.standardOutput = pipe
      process.standardError = pipe
      do {
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        result =
          String(data: data, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      } catch {
        result = "Process failed: \(error.localizedDescription)"
      }
      DispatchQueue.main.async {
        output = result
        isRunning = false
      }
    }
  }
}

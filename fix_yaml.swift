import Foundation

let configPath = "/Users/shin/.config/kamidana/config.yaml"
let yamlString = try String(contentsOfFile: configPath, encoding: .utf8)

var newLines = [String]()
var inDisplays = false
var hasAddedDisplays = false

for line in yamlString.components(separatedBy: .newlines) {
    if line.hasPrefix("external:") {
        newLines.append("displays:")
        hasAddedDisplays = true
        newLines.append("  external:")
        inDisplays = true
    } else if line.hasPrefix("built_in:") {
        if !hasAddedDisplays {
            newLines.append("displays:")
            hasAddedDisplays = true
        }
        newLines.append("  built_in:")
        inDisplays = true
    } else if line.hasPrefix("global:") {
        newLines.append(line)
        inDisplays = false
    } else {
        if inDisplays && !line.isEmpty {
            newLines.append("  " + line)
        } else {
            newLines.append(line)
        }
    }
}

let result = newLines.joined(separator: "\n")
try result.write(toFile: configPath, atomically: true, encoding: .utf8)
print("Config updated!")

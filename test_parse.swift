import Foundation
import Yams

let configPath = "/Users/shin/.config/kamidana/config.yaml"
let yamlString = try String(contentsOfFile: configPath, encoding: .utf8)
do {
    let dict = try Yams.load(yaml: yamlString) as? [String: Any]
    let displays = dict?["displays"] as? [String: Any]
    print("Parsed displays keys: \(displays?.keys.map { $0 } ?? [])")
} catch {
    print("Parse error: \(error)")
}

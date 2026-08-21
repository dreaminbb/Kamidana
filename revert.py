import re

with open("Sources/KamidanaApp/config/KamidanaConfigurationV1.swift", "r") as f:
    text = f.read()

text = text.replace("public var monitor: [String]?\n", "")
text = text.replace("    monitor: [String]? = nil,\n", "")
text = text.replace("    self.monitor = monitor\n", "")
text = text.replace("    case monitor\n", "")
text = text.replace("      monitor: try container.decodeIfPresent([String].self, forKey: .monitor),\n", "")

with open("Sources/KamidanaApp/config/KamidanaConfigurationV1.swift", "w") as f:
    f.write(text)

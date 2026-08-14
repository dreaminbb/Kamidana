import Foundation

public class NerdFontManager {
    public static let shared = NerdFontManager()
    private var icons: [String: String] = [:]
    
    private init() {
        loadConfig()
    }
    
    public func icon(for key: String) -> String? {
        return icons[key]
    }
    
    private func loadConfig() {
        let configPath = "/Users/shin/Developer/Kamidana/nerdfont.toml"
        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("⚠️ TOMLファイルが読み込めませんでした: \(configPath)")
            return
        }
        
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("[") { continue }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                let key = parts[0]
                var value = parts[1]
                
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                
                value = unescapeUnicode(value)
                icons[key] = value
            }
        }
    }
    
    private func unescapeUnicode(_ string: String) -> String {
        var result = string
        if let regex = try? NSRegularExpression(pattern: "\\\\u([0-9a-fA-F]{4,8})") {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result),
                   let hexCode = UInt32(result[range], radix: 16),
                   let scalar = UnicodeScalar(hexCode) {
                    let replaceRange = Range(match.range, in: result)!
                    result.replaceSubrange(replaceRange, with: String(scalar))
                }
            }
        }
        return result
    }
}

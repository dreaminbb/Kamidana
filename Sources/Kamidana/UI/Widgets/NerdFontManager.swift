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

    /// Resolves the file path for nerdfont.toml based on the execution context.
    ///
    /// Resolution strategy:
    /// 1. Bundle resources directory (e.g. `Bundle.main.resourcePath + "/nerdfont.toml"` in a macOS .app bundle).
    ///    Note: `nerdfont.toml` should be copied into the app bundle Resources directory during the build process.
    /// 2. Executable parent directories (e.g. searching up from the executable directory to find the project root when running via `swift run`).
    /// 3. Current working directory fallback (`./nerdfont.toml`).
    private func resolveConfigPath() -> String? {
        let fileManager = FileManager.default

        // 1. First try: Bundle resource path (for .app bundle with Resources)
        if let resourcePath = Bundle.main.resourcePath {
            let resourceConfigPath = (resourcePath as NSString).appendingPathComponent("nerdfont.toml")
            if fileManager.fileExists(atPath: resourceConfigPath) {
                return resourceConfigPath
            }
        }

        // Check directly inside bundle path if resourcePath did not locate it
        let bundleConfigPath = (Bundle.main.bundlePath as NSString).appendingPathComponent("nerdfont.toml")
        if fileManager.fileExists(atPath: bundleConfigPath) {
            return bundleConfigPath
        }

        // 2. Second try: Executable's parent directory hierarchy (project root when running via `swift run`)
        if let executablePath = Bundle.main.executablePath {
            var url = URL(fileURLWithPath: executablePath).deletingLastPathComponent()
            for _ in 0..<5 {
                url = url.deletingLastPathComponent()
                let candidatePath = url.appendingPathComponent("nerdfont.toml").path
                if fileManager.fileExists(atPath: candidatePath) {
                    return candidatePath
                }
            }
        }

        // 3. Fallback: Current working directory
        let fallbackPath = "./nerdfont.toml"
        if fileManager.fileExists(atPath: fallbackPath) {
            return fallbackPath
        }

        return nil
    }

    private func loadConfig() {
        guard let configPath = resolveConfigPath() else {
            print("[NerdFontManager] Could not find nerdfont.toml configuration file")
            return
        }

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            print("[NerdFontManager] Failed to read configuration file: \(configPath)")
            return
        }

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix("[") { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
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

    /// Unescapes unicode escape sequences (e.g. `\uXXXX`) if present.
    /// Note: While the TOML configuration now contains raw Unicode characters,
    /// this method is preserved as a safety net for escaped Unicode sequences.
    private func unescapeUnicode(_ string: String) -> String {
        var result = string
        if let regex = try? NSRegularExpression(pattern: "\\\\u([0-9a-fA-F]{4,8})") {
            let matches = regex.matches(
                in: result, range: NSRange(result.startIndex..., in: result))

            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result),
                    let hexCode = UInt32(result[range], radix: 16),
                    let scalar = UnicodeScalar(hexCode)
                {
                    let replaceRange = Range(match.range, in: result)!
                    result.replaceSubrange(replaceRange, with: String(scalar))
                }
            }
        }
        return result
    }
}


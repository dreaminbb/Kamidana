import AppKit

final class ProcessMetadataCache {
    static let shared = ProcessMetadataCache()
    
    private struct Metadata {
        let name: String
        let icon: NSImage?
    }
    
    private var cache: [String: Metadata] = [:]
    
    func metadata(forPath path: String) -> (name: String, icon: NSImage?) {
        if let existing = cache[path] {
            return (existing.name, existing.icon)
        }
        
        let name = URL(fileURLWithPath: path).lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        let data = Metadata(name: name, icon: icon)
        cache[path] = data
        
        // Prevent infinite growth
        if cache.count > 1000 {
            cache.removeAll()
        }
        
        return (data.name, data.icon)
    }
    
    func metadata(forPID pid: pid_t) -> (name: String, icon: NSImage?)? {
        if let app = NSRunningApplication(processIdentifier: pid), let url = app.executableURL {
            let path = url.path
            if let existing = cache[path] {
                return (existing.name, existing.icon)
            }
            let name = app.localizedName ?? url.lastPathComponent
            let icon = app.icon ?? NSWorkspace.shared.icon(forFile: path)
            let data = Metadata(name: name, icon: icon)
            cache[path] = data
            if cache.count > 1000 { cache.removeAll() }
            return (data.name, data.icon)
        }
        return nil
    }
}

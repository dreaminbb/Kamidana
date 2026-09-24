import Combine
import CryptoKit
import Foundation
import ImageIO

struct MusicArtworkKey: Hashable {
    let filename: String

    init(snapshot: MusicPlaybackSnapshot) {
        let provider = snapshot.app == .spotify ? "spotify" : "apple-music"
        let components: [String]
        if snapshot.app == .spotify, let url = snapshot.artworkURL {
            // An album's tracks commonly share the same immutable Spotify image URL.
            components = ["v1", provider, "url", url.absoluteString]
        } else {
            components = ["v1", provider, "track", snapshot.sourceIdentifier,
                          snapshot.title, snapshot.artist, snapshot.album]
        }
        let value = components.map { "\($0.utf8.count):\($0)" }.joined()
        filename = SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }.joined() + ".artwork"
    }
}

protocol MusicArtworkLoading: AnyObject {
    typealias Source = (@escaping (Data?) -> Void) -> AnyCancellable?

    /// Completion is asynchronous on the main queue. Retain the returned subscription.
    func load(
        key: MusicArtworkKey,
        source: @escaping Source,
        completion: @escaping (CGImage?) -> Void
    ) -> AnyCancellable
}

/// Queue-confined cache state, file access, and image decoding.
final class MusicArtworkCache: MusicArtworkLoading {
    static let shared = MusicArtworkCache()
    static let maximumSourceBytes = 8 * 1024 * 1024

    struct Limits {
        var memoryBytes = 32 * 1024 * 1024
        var memoryCount = 32
        var diskBytes = 128 * 1024 * 1024
        var diskCount = 200
        var maximumAge: TimeInterval = 30 * 24 * 60 * 60
        var maximumSourceBytes = MusicArtworkCache.maximumSourceBytes
        var maximumPixelCount = 40_000_000
        var thumbnailSize = 512
        var maximumFlights = 8
    }

    private struct MemoryEntry {
        let image: CGImage
        let cost: Int
        let created: Date
        var access: UInt64
    }

    private struct Flight {
        let id: UUID
        var subscribers: [UUID: (CGImage?) -> Void]
        var request: AnyCancellable?
    }

    private let queue = DispatchQueue(label: "com.shin.Kamidana.artwork-cache", qos: .utility)
    private let directory: URL?
    private let limits: Limits
    private let now: () -> Date
    private let files = FileManager.default
    private var memory: [MusicArtworkKey: MemoryEntry] = [:]
    private var memoryCost = 0
    private var access: UInt64 = 0
    private var flights: [MusicArtworkKey: Flight] = [:]

    init(
        directory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("com.shin.Kamidana/Artwork/v1", isDirectory: true),
        limits: Limits = Limits(),
        now: @escaping () -> Date = Date.init
    ) {
        self.directory = directory
        self.limits = limits
        self.now = now
        queue.async { [weak self] in self?.pruneDisk() }
    }

    func load(
        key: MusicArtworkKey,
        source: @escaping Source,
        completion: @escaping (CGImage?) -> Void
    ) -> AnyCancellable {
        let subscriber = UUID()
        let state = MusicArtworkCancellation()
        let deliver: (CGImage?) -> Void = { image in
            DispatchQueue.main.async {
                guard !state.isCancelled else { return }
                completion(image)
            }
        }
        queue.async { [weak self] in
            guard let self, !state.isCancelled else { return }
            if let image = self.cachedImage(for: key) {
                deliver(image)
                return
            }
            if self.flights[key] != nil {
                self.flights[key]?.subscribers[subscriber] = deliver
                return
            }
            guard self.flights.count < self.limits.maximumFlights else {
                deliver(nil)
                return
            }
            let flightID = UUID()
            self.flights[key] = Flight(id: flightID, subscribers: [subscriber: deliver])
            let request = source { [weak self] data in
                guard let self else { return }
                self.queue.async {
                    guard self.flights[key]?.id == flightID else { return }
                    let image = data.flatMap(self.validatedImage)
                    if let image, let data {
                        self.insert(image, for: key, created: self.now())
                        self.write(data, for: key)
                    }
                    let flight = self.flights.removeValue(forKey: key)
                    flight?.subscribers.values.forEach { $0(image) }
                }
            }
            self.flights[key]?.request = request
        }
        return AnyCancellable { [weak self] in
            state.cancel()
            self?.queue.async { [weak self] in
                guard let self else { return }
                self.flights[key]?.subscribers.removeValue(forKey: subscriber)
                if self.flights[key]?.subscribers.isEmpty == true {
                    let flight = self.flights.removeValue(forKey: key)
                    flight?.request?.cancel()
                }
            }
        }
    }

    private func cachedImage(for key: MusicArtworkKey) -> CGImage? {
        access &+= 1
        if var entry = memory[key] {
            if now().timeIntervalSince(entry.created) < limits.maximumAge {
                entry.access = access
                memory[key] = entry
                touch(key)
                return entry.image
            }
            memoryCost -= entry.cost
            memory.removeValue(forKey: key)
        }
        guard let url = directory?.appendingPathComponent(key.filename) else { return nil }
        do {
            let values = try url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .creationDateKey,
            ])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let size = values.fileSize, size > 0, size <= limits.maximumSourceBytes,
                  let created = values.creationDate,
                  now().timeIntervalSince(created) < limits.maximumAge
            else {
                try? files.removeItem(at: url)
                return nil
            }
            let data = try Data(contentsOf: url)
            guard let image = validatedImage(data) else {
                try? files.removeItem(at: url)
                return nil
            }
            insert(image, for: key, created: created)
            touch(key)
            return image
        } catch {
            return nil
        }
    }

    private func validatedImage(_ data: Data) -> CGImage? {
        guard !data.isEmpty, data.count <= limits.maximumSourceBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetStatus(source) == .statusComplete,
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= Double(limits.maximumPixelCount)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, limits.thumbnailSize),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete
        else { return nil }
        return image
    }

    private func insert(_ image: CGImage, for key: MusicArtworkKey, created: Date) {
        let cost = image.bytesPerRow * image.height
        guard cost <= limits.memoryBytes, limits.memoryCount > 0 else { return }
        if let old = memory.removeValue(forKey: key) { memoryCost -= old.cost }
        access &+= 1
        memory[key] = MemoryEntry(image: image, cost: cost, created: created, access: access)
        memoryCost += cost
        while memoryCost > limits.memoryBytes || memory.count > limits.memoryCount {
            guard let oldest = memory.min(by: { $0.value.access < $1.value.access }) else { break }
            memoryCost -= oldest.value.cost
            memory.removeValue(forKey: oldest.key)
        }
    }

    private func touch(_ key: MusicArtworkKey) {
        guard let url = directory?.appendingPathComponent(key.filename) else { return }
        try? files.setAttributes([.modificationDate: now()], ofItemAtPath: url.path)
    }

    private func write(_ data: Data, for key: MusicArtworkKey) {
        guard let directory, data.count <= limits.diskBytes, limits.diskCount > 0 else { return }
        do {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(key.filename)
            try data.write(to: url, options: .atomic)
            try files.setAttributes([.creationDate: now(), .modificationDate: now()], ofItemAtPath: url.path)
            pruneDisk()
        } catch {
            // A cache is disposable; memory remains usable on a read-only or full disk.
        }
    }

    private func pruneDisk() {
        guard let directory,
              let urls = try? files.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                                              .fileSizeKey, .creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
              )
        else { return }
        var entries: [(url: URL, bytes: Int, accessed: Date)] = []
        for url in urls where url.pathExtension == "artwork" {
            guard let values = try? url.resourceValues(forKeys: [
                .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
                .creationDateKey, .contentModificationDateKey,
            ]), values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            let size = values.fileSize ?? 0
            let created = values.creationDate ?? .distantPast
            if size <= 0 || size > limits.maximumSourceBytes
                || now().timeIntervalSince(created) >= limits.maximumAge {
                try? files.removeItem(at: url)
            } else {
                entries.append((url, size, values.contentModificationDate ?? .distantPast))
            }
        }
        entries.sort { $0.accessed < $1.accessed }
        var bytes = entries.reduce(0) { $0 + $1.bytes }
        var count = entries.count
        for entry in entries {
            guard bytes > limits.diskBytes || count > limits.diskCount else { break }
            do {
                try files.removeItem(at: entry.url)
                bytes -= entry.bytes
                count -= 1
            } catch {
                continue
            }
        }
    }
}

/// Shared by the caller and queued delivery, including callbacks already enqueued on main.
final class MusicArtworkCancellation {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

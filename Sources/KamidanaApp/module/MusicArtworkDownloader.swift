import Combine
import Foundation

/// Streaming avoids buffering an unbounded response before enforcing the image-size limit.
final class MusicArtworkDownloader: NSObject, URLSessionDataDelegate {
    private let maximumBytes: Int
    private var completion: ((Data?) -> Void)?
    private var bytes = Data()
    private var session: URLSession?

    private init(maximumBytes: Int, completion: @escaping (Data?) -> Void) {
        self.maximumBytes = maximumBytes
        self.completion = completion
    }

    static func load(
        _ url: URL,
        configuration: URLSessionConfiguration = .ephemeral,
        maximumBytes: Int = MusicArtworkCache.maximumSourceBytes,
        completion: @escaping (Data?) -> Void
    ) -> AnyCancellable? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
            completion(nil)
            return nil
        }
        let delegate = MusicArtworkDownloader(maximumBytes: maximumBytes, completion: completion)
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        delegate.session = session
        let task = session.dataTask(with: url)
        task.resume()
        return AnyCancellable { task.cancel() }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              response.expectedContentLength <= Int64(maximumBytes)
        else {
            completionHandler(.cancel)
            finish(nil)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard data.count <= maximumBytes - bytes.count else {
            dataTask.cancel()
            finish(nil)
            return
        }
        bytes.append(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        finish(error == nil && !bytes.isEmpty ? bytes : nil)
    }

    private func finish(_ data: Data?) {
        let callback = completion
        completion = nil
        bytes.removeAll()
        session?.invalidateAndCancel()
        session = nil
        callback?(data)
    }
}

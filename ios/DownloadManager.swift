
import Foundation
import UIKit

actor DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    private var backgroundSession: URLSession!
    private var completionHandlers: [URL: (URL?) -> Void] = [:]

    private override init() {
        super.init()
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.example.audiobooks.bgdownloads")
        cfg.isDiscretionary = false
        cfg.sessionSendsLaunchEvents = true
        backgroundSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func localURL(for remote: URL) -> URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = url.appendingPathComponent("Audio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(remote.lastPathComponent)
    }

    func isDownloaded(_ remote: URL) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: remote).path)
    }

    func download(_ remote: URL, completion: @escaping (URL?) -> Void) {
        if isDownloaded(remote) { completion(localURL(for: remote)); return }
        let task = backgroundSession.downloadTask(with: remote)
        completionHandlers[remote] = completion
        task.resume()
    }

    func download(_ remote: URL) async throws -> URL {
        if isDownloaded(remote) { return localURL(for: remote) }
        return try await withCheckedThrowingContinuation { cont in
            download(remote) { local in
                if let l = local { cont.resume(returning: l) }
                else { cont.resume(throwing: NSError(domain: "Download", code: -1)) }
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let source = downloadTask.originalRequest?.url else { return }
        let dest = localURL(for: source)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            DispatchQueue.main.async {
                self.completionHandlers[source]?(dest)
                self.completionHandlers[source] = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.completionHandlers[source]?(nil)
                self.completionHandlers[source] = nil
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let url = task.originalRequest?.url, let _ = error {
            DispatchQueue.main.async {
                self.completionHandlers[url]?(nil)
                self.completionHandlers[url] = nil
            }
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            if let handler = AppDelegate.backgroundCompletionHandler {
                AppDelegate.backgroundCompletionHandler = nil
                handler()
            }
        }
    }
}

import Foundation

actor DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config,
                          delegate: self,
                          delegateQueue: nil)
    }()

    private var completions: [URL: (URL?) -> Void] = [:]

    // MARK: - Public API
    func download(_ url: URL) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url)
            completions[url] = { localUrl in
                if let localUrl = localUrl {
                    continuation.resume(returning: localUrl)
                } else {
                    continuation.resume(throwing: URLError(.cannotDecodeContentData))
                }
            }
            task.resume()
        }
    }

    // MARK: - URLSessionDownloadDelegate
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        Task {
            let url = downloadTask.originalRequest?.url
            await self.handleDownloadFinished(url: url, location: location)
        }
    }

    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        if let error = error {
            print("Download failed: \(error)")
        }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("Background session finished events")
    }

    // MARK: - Internal
    private func handleDownloadFinished(url: URL?, location: URL) {
        guard let url else { return }
        let completion = completions.removeValue(forKey: url)
        completion?(location)
    }
}

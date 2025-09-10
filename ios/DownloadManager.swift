import Foundation

actor DownloadManager: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    static let shared = DownloadManager()
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private var activeTasks: [URL: URLSessionDownloadTask] = [:]
    private let fileManager = FileManager.default
    
    /// Скачивание файла и возврат локального URL
    func download(_ url: URL) async throws -> URL {
        if let existing = activeTasks[url] {
            return try await existing.value(forKey: "response") as! URL // безопаснее потом заменить
        }
        
        let (localURL, _) = try await session.download(from: url)
        return localURL
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated func urlSession(_ session: URLSession,
                                downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        Task { [weak self] in
            guard let self else { return }
            let destination = self.localFileURL(for: downloadTask.originalRequest?.url)
            do {
                if self.fileManager.fileExists(atPath: destination.path) {
                    try self.fileManager.removeItem(at: destination)
                }
                try self.fileManager.moveItem(at: location, to: destination)
                print("✅ Download finished: \(destination.lastPathComponent)")
            } catch {
                print("❌ File move failed: \(error)")
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession,
                                task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        if let error {
            print("❌ Download failed: \(error.localizedDescription)")
        }
    }
    
    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("ℹ️ Background session events finished")
    }
    
    // MARK: - Helpers
    
    private func localFileURL(for url: URL?) -> URL {
        guard let url else { return FileManager.default.temporaryDirectory }
        let fileName = url.lastPathComponent
        let dir = fileManager.temporaryDirectory
        return dir.appendingPathComponent(fileName)
    }
}

import Foundation

class DownloadManager: NSObject, URLSessionDownloadDelegate, URLSessionTaskDelegate {
    static let shared = DownloadManager()
    
    private var session: URLSession!
    private var activeDownloads: [URL: URLSessionDownloadTask] = [:]
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.audiobooks.download")
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    // Начать загрузку
    func startDownload(from url: URL) {
        if activeDownloads[url] != nil {
            return // уже качается
        }
        let task = session.downloadTask(with: url)
        activeDownloads[url] = task
        task.resume()
    }
    
    // Отменить загрузку
    func cancelDownload(for url: URL) {
        activeDownloads[url]?.cancel()
        activeDownloads.removeValue(forKey: url)
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        print("✅ Загрузка завершена: \(location)")
        if let originalURL = downloadTask.originalRequest?.url {
            activeDownloads.removeValue(forKey: originalURL)
        }
        // TODO: переместить файл из временной папки в постоянное хранилище
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ Ошибка загрузки: \(error.localizedDescription)")
        } else {
            print("ℹ️ Задача завершена успешно")
        }
        if let url = task.originalRequest?.url {
            activeDownloads.removeValue(forKey: url)
        }
    }
    
    // MARK: - Background events
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("🌙 Все события для background session завершены")
        // Если нужно, дернуть completionHandler из AppDelegate
    }
}

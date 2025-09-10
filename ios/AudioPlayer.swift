
import AVFoundation
import SwiftUI

final class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()
    private var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var rate: Float = 1.0
    private var sleepTimer: Timer?
    private var currentTrackURL: URL?
    private var currentBookId: String?
    private var currentChapterId: String?

    func play(url: URL, bookId: String? = nil, chapterId: String? = nil) {
        currentTrackURL = url
        currentBookId = bookId
        currentChapterId = chapterId
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try? AVAudioSession.sharedInstance().setActive(true)
        } else {
            player?.replaceCurrentItem(with: item)
        }

        if let b = bookId, let c = chapterId, let pos = ProgressStore.shared.loadProgress(bookId: b, chapterId: c) {
            let cm = CMTime(seconds: pos, preferredTimescale: 600)
            player?.seek(to: cm)
        }

        setRate(rate)
        player?.play()
        isPlaying = true

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if let b = self.currentBookId, let c = self.currentChapterId {
                ProgressStore.shared.clearProgress(bookId: b, chapterId: c)
            }
            self.isPlaying = false
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        if let b = currentBookId, let c = currentChapterId, let time = player?.currentTime().seconds, time.isFinite {
            ProgressStore.shared.saveProgress(bookId: b, chapterId: c, position: time)
        }
    }

    func setRate(_ r: Float) {
        rate = max(0.5, min(2.0, r))
        player?.rate = isPlaying ? rate : 0.0
    }

    func startSleepTimer(seconds: TimeInterval) {
        sleepTimer?.invalidate()
        sleepTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.pause()
        }
    }

    func startSleepTimerToEndOfChapter() {
        guard let current = player?.currentItem?.duration, current.isNumeric,
              let now = player?.currentTime(), now.isNumeric else { return }
        let remaining = current.seconds - now.seconds
        if remaining.isFinite && remaining > 0 { startSleepTimer(seconds: remaining + 0.5) }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate(); sleepTimer = nil
    }
}

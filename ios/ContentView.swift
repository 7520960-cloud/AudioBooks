import SwiftUI

struct Book: Identifiable {
    let id = UUID()
    let identifier: String
    let title: String
    let description: String
    let isPro: Bool
    let streamUrls: [URL]
}

struct ContentView: View {
    @StateObject private var store = Store()
    
    private let demo = Book(
        identifier: "demo",
        title: "Пример книги",
        description: "Демо-описание",
        isPro: true,
        streamUrls: [
            URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!
        ]
    )
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                NavigationLink("Открыть книгу") {
                    BookDetail(book: demo)
                        .environmentObject(store)
                }
                Button("Открыть Paywall") { }
                    .sheet(isPresented: .constant(false)) {
                        PaywallView().environmentObject(store)
                    }
            }
            .navigationTitle("Аудиокниги")
            .padding()
        }
    }
}

struct BookDetail: View {
    let book: Book
    @StateObject private var audio = AudioPlayer.shared
    @EnvironmentObject private var store: Store
    
    var body: some View {
        List {
            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.title2).bold()
                Text(book.description)
            }
            
            Section(header: Text("Главы")) {
                ForEach(Array(book.streamUrls.enumerated()), id: \.offset) { idx, url in
                    let chapterId = "part_\(idx)"
                    let locked = book.isPro && !store.isSubscribed && idx >= 1
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Часть \(idx + 1)")
                            if let pos = ProgressStore.shared.loadProgress(bookId: book.identifier, chapterId: chapterId) {
                                ProgressView(value: min(pos / 3000, 1.0))
                                    .frame(height: 6)
                                Text("Прогресс: \(Int(pos)) сек")
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        if locked {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if locked {
                            print("Show paywall")
                        } else {
                            Task {
                                if let local = try? await DownloadManager.shared.download(url) {
                                    await audio.play(url: local, bookId: book.identifier, chapterId: chapterId)
                                } else {
                                    await audio.play(url: url, bookId: book.identifier, chapterId: chapterId)
                                }
                            }
                        }
                    }
                }
                
                HStack {
                    Button("Пауза") { audio.pause() }
                    Button("Таймер: конец главы") { audio.startSleepTimerToEndOfChapter() }
                    Button("Таймер: 15 мин") { audio.startSleepTimer(seconds: 15 * 60) }
                }
            }
        }
        .navigationTitle(book.title)
    }
}

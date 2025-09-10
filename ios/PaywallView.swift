
import SwiftUI

struct PaywallProduct: Codable, Hashable {
    let id: String
    let title: String
    let price: String
}

struct PaywallResponse: Codable {
    let title: String
    let subtitle: String
    let features: [String]
    let products: [PaywallProduct]
    let bannerUrl: String?
    let variant: String?
}

@MainActor
struct PaywallView: View {
    @EnvironmentObject var store: Store
    @State private var model: PaywallResponse?
    @State private var isLoading = true
    @State private var showError = false
    var variant: String? = nil // A/B override

    var body: some View {
        VStack(spacing: 16) {
            if isLoading {
                ProgressView("Загрузка...")
            } else if let m = model {
                if let urlStr = m.bannerUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { img in
                        img.resizable().aspectRatio(contentMode: .fill).frame(height: 160).clipped().cornerRadius(8)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 160).cornerRadius(8)
                    }
                }
                Text(m.title).font(.largeTitle).bold()
                Text(m.subtitle).foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(m.features, id: \ .self) { f in
                        HStack { Image(systemName: "checkmark.circle"); Text(f) }
                    }
                }.padding(.vertical)
                Spacer()
                if let v = m.variant { Text("Variant: \(v)").font(.caption).foregroundColor(.secondary) }
                ForEach(m.products, id: \ .self) { p in
                    Button(action: { Task { await purchase(productId: p.id) } }) {
                        HStack { Text(p.title); Spacer(); Text(p.price) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Restore Purchases") { Task { await store.restore() } }.padding(.top, 8)
            } else {
                Text(showError ? "Paywall unavailable" : "No data").foregroundColor(.secondary)
            }
        }
        .padding()
        .task { await load() }
    }

    func load() async {
        isLoading = true; defer { isLoading = false }
        let lang = Locale.current.identifier
        var urlStr = "http://localhost:8080/api/paywall?lang=\(lang)"
        if let v = variant { urlStr += "&variant=\(v)" }
        if let token = Store.appAccountTokenString() { urlStr += "&appAccountToken=\(token)" }
        guard let url = URL(string: urlStr) else { showError = true; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            model = try JSONDecoder().decode(PaywallResponse.self, from: data)
        } catch { print("Paywall fetch failed:", error); showError = true }
    }

    func purchase(productId: String) async {
        await store.purchase(productId: productId)
        if let token = Store.appAccountTokenString() {
            await store.sendReceiptToServer(appAccountToken: token)
        }
    }
}

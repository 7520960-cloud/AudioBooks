
import Foundation
import StoreKit
import CryptoKit

final class Store: ObservableObject {
    @Published var isSubscribed: Bool = false
    static let tokenKey = "app_account_token"

    func purchase(productId: String? = nil) async {
        // Placeholder: integrate StoreKit 2 purchases here and set isSubscribed = true on success
        await MainActor.run { self.isSubscribed = true }
    }

    func restore() async {
        // Placeholder: call StoreKit restore
        await MainActor.run { self.isSubscribed = true }
    }

    static func appAccountTokenString() -> String? {
        if let s = UserDefaults.standard.string(forKey: tokenKey) { return s }
        let new = UUID().uuid4String
        UserDefaults.standard.set(new, forKey: tokenKey)
        return new
    }

    func fetchLocalReceiptBase64() -> String? {
        guard let url = Bundle.main.appStoreReceiptURL, let data = try? Data(contentsOf: url) else { return nil }
        return data.base64EncodedString()
    }

    func sendReceiptToServer(appAccountToken: String) async {
        guard let receipt = fetchLocalReceiptBase64() else { return }
        guard let url = URL(string: "http://localhost:8080/api/validate-receipt") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["receiptData": receipt, "appAccountToken": appAccountToken]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
               let isValid = json["isValid"] as? Bool, isValid {
                await MainActor.run { self.isSubscribed = true }
            }
        } catch { print("sendReceiptToServer failed:", error) }
    }
}

private extension UUID {
    var uuid4String: String { uuidString.lowercased() }
}

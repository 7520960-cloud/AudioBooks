
# Audiobooks (v12 rebuild)
- iOS (SwiftUI): Core Data progress per chapter, sleep timer to end-of-chapter, background downloads, modal Paywall (server-driven, A/B), StoreKit Test config.
- Backend (Node/Express + SQLite): /health, /api/paywall (A/B + banner), /api/validate-receipt (verifyReceipt), /apple/assn (stub).

## iOS quick start
1) Open in Xcode, set `PRODUCT_BUNDLE_IDENTIFIER` and `DEVELOPMENT_TEAM` in `ios/project.yml` (or project settings).
2) Ensure Background Modes (audio) and In-App Purchases are enabled.
3) Scheme → StoreKit Configuration → `Audiobooks.storekit`.
4) Run on simulator.

## Backend
```bash
cd backend
npm i express better-sqlite3 node-fetch@2 dotenv cors body-parser
node server.js
```
- GET /health
- GET /api/paywall?lang=ru-RU&appAccountToken=<uuid>
- POST /api/validate-receipt { receiptData, appAccountToken }

## CI
- Fastlane lanes: `beta`, `release`
- GitHub Actions workflow: `.github/workflows/ios.yml`

## Notes
- Replace placeholders: bundle id, team id, ASC_SHARED_SECRET, backend URL in iOS.
- StoreKit purchase methods in `Store` are placeholders; wire to StoreKit 2 for real purchases.

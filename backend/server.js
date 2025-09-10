
// Minimal Express server with SQLite, ASSN v2 stub, paywall, and receipt validation
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
require('dotenv').config();

const app = express();
app.use(cors());
app.use(bodyParser.json({limit: '2mb'}));

const db = new Database(process.env.SQLITE_FILE || './audiobooks.db');

db.exec(`
CREATE TABLE IF NOT EXISTS subscriptions (
  originalTransactionId TEXT PRIMARY KEY,
  bundleId TEXT,
  status TEXT,
  environment TEXT,
  lastUpdate INTEGER
);
`);

// A/B assignment
db.exec(`CREATE TABLE IF NOT EXISTS users_ab (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  appAccountToken TEXT UNIQUE,
  variant TEXT,
  assignedAt INTEGER
);`);

// receipts table
db.exec(`CREATE TABLE IF NOT EXISTS receipts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  appAccountToken TEXT,
  receiptData TEXT,
  isValid INTEGER,
  responseJSON TEXT,
  checkedAt INTEGER
);
`);

app.get('/health', (_req, res) => res.json({status:'ok'}));

// Server-driven paywall with A/B and banner
app.get('/api/paywall', (req, res) => {
  const lang = (req.query.lang || 'en-US').toString();
  const override = (req.query.variant || null);
  const appAccountToken = req.query.appAccountToken || null;
  let variant = override || 'A';
  try {
    if (appAccountToken) {
      const row = db.prepare('SELECT variant FROM users_ab WHERE appAccountToken = ?').get(appAccountToken);
      if (row && row.variant) variant = row.variant;
      else {
        variant = Math.random() < 0.5 ? 'A' : 'B';
        db.prepare('INSERT OR REPLACE INTO users_ab (appAccountToken, variant, assignedAt) VALUES (?,?,?)').run(appAccountToken, variant, Date.now());
      }
    }
  } catch(e) { console.warn('AB error', e); }

  const base = {
    "en-US": {
      title: "Unlock the full catalog",
      subtitle: "Listen without limits",
      features: ["🎧 1000+ public-domain books", "📥 Offline downloads", "🚫 No ads"],
      bannerUrl: "https://placehold.co/600x200?text=A",
      products: [
        { id: "com.example.audiobooks.premium_monthly", title: "Monthly", price: "4.99" },
        { id: "com.example.audiobooks.premium_yearly", title: "Yearly", price: "49.99" },
        { id: "com.example.audiobooks.full_unlock", title: "Lifetime", price: "99.99" }
      ]
    },
    "ru-RU": {
      title: "Открой весь каталог",
      subtitle: "Слушай без ограничений",
      features: ["🎧 1000+ книг в публичном доступе", "📥 Офлайн загрузки", "🚫 Без рекламы"],
      bannerUrl: "https://placehold.co/600x200?text=RU_A",
      products: [
        { id: "com.example.audiobooks.premium_monthly", title: "Месяц", price: "4.99" },
        { id: "com.example.audiobooks.premium_yearly", title: "Год", price: "49.99" },
        { id: "com.example.audiobooks.full_unlock", title: "Навсегда", price: "99.99" }
      ]
    }
  };
  let payload = base[lang] || base['en-US'];
  if (variant === 'B') {
    payload.subtitle += " — special 30% off on Yearly";
    payload.features = payload.features.concat(["🔥 Variant B: 30% off yearly"]);
    payload.bannerUrl = (payload.bannerUrl || "").replace("A","B");
  }
  payload.variant = variant;
  res.json(payload);
});

// verifyReceipt helper
async function verifyReceiptWithApple(receiptBase64) {
  const secret = process.env.ASC_SHARED_SECRET || null;
  const prodUrl = 'https://buy.itunes.apple.com/verifyReceipt';
  const sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
  const body = { 'receipt-data': receiptBase64 };
  if (secret) body.password = secret;

  let resp = await fetch(prodUrl, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
  let json = await resp.json();
  if (json && json.status === 21007) {
    resp = await fetch(sandboxUrl, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
    json = await resp.json();
  }
  return json;
}

app.post('/api/validate-receipt', async (req, res) => {
  try {
    const { receiptData, appAccountToken } = req.body || {};
    if (!receiptData) return res.status(400).json({ error: 'missing_receipt' });
    const verification = await verifyReceiptWithApple(receiptData);
    const now = Date.now();
    const isValid = (verification && (verification.status === 0 || verification.status === '0')) ? 1 : 0;
    db.prepare('INSERT INTO receipts (appAccountToken, receiptData, isValid, responseJSON, checkedAt) VALUES (?,?,?,?,?)')
      .run(appAccountToken || null, receiptData, isValid, JSON.stringify(verification), now);
    if (isValid && appAccountToken) {
      db.prepare('INSERT OR REPLACE INTO subscriptions (originalTransactionId, bundleId, status, environment, lastUpdate) VALUES (?,?,?,?,?)')
        .run(String(appAccountToken), 'com.example.audiobooks', 'validated', process.env.APPLE_NOTIFICATION_ENV || 'SANDBOX', now);
    }
    res.json({ ok: true, isValid: !!isValid, verification });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e) });
  }
});

// ASSN v2 stub endpoint (expects JWS verification done elsewhere)
app.post('/apple/assn', (req, res) => {
  try {
    const data = req.body || {};
    const bundleId = data.bundleId || 'com.example.audiobooks';
    const status = data.notificationType || 'unknown';
    const environment = data.environment || (process.env.APPLE_NOTIFICATION_ENV || 'SANDBOX');
    const now = Date.now();
    const originalTransactionId = data.appAccountToken || data.originalTransactionId || 'unknown';
    db.prepare('INSERT OR REPLACE INTO subscriptions (originalTransactionId, bundleId, status, environment, lastUpdate) VALUES (?,?,?,?,?)')
      .run(String(originalTransactionId), String(bundleId), String(status), String(environment), now);
    res.json({ ok: true });
  } catch(e) {
    console.error('ASSN error', e);
    res.status(500).json({ error: String(e) });
  }
});

const port = process.env.PORT || 8080;
app.listen(port, () => console.log('Server listening on', port));

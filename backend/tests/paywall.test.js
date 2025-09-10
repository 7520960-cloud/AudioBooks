
const fetch = require('node-fetch');
describe('Paywall endpoint', () => {
  const base = process.env.BASE_URL || 'http://localhost:8080';
  it('returns payload', async () => {
    const res = await fetch(`${base}/api/paywall?lang=en-US`);
    const data = await res.json();
    if (!data.title || !Array.isArray(data.features) || !Array.isArray(data.products)) {
      throw new Error('Invalid payload structure');
    }
  }, 15000);
});

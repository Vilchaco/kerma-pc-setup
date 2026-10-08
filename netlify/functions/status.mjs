// Kerma PC Setup - status of every PC, stored in Netlify Blobs (store "kerma-status").
//   POST   /api/register      (x-pin)        -> { key }  write key for a PC (the setup script asks for the PIN once)
//   POST   /api/status        (x-kerma-key)  -> a PC reports its status (Kerma-Status.ps1, every 5 min)
//   GET    /api/status        (x-pin)        -> { now, pcs: [...] }
//   DELETE /api/status?id=... (x-pin)        -> forget a PC (renamed / retired)
// Environment: STATUS_PIN (people) and STATUS_WRITE_KEY (PCs). Never in the repo: it is public.
// 5 wrong PINs in 15 min lock the PIN for 15 min (blob lock/fails), same as Kerma Tips.
import { getStore } from '@netlify/blobs';

export const config = { path: ['/api/status', '/api/register'] };

const json = (data, status = 200) =>
  new Response(JSON.stringify(data), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

async function checkPin(req, store) {
  const pin = process.env.STATUS_PIN;
  if (!pin) return json({ error: 'not-configured', msg: 'STATUS_PIN is missing in Netlify' }, 503);
  const fails = (await store.get('lock/fails', { type: 'json' })) || { n: 0, since: 0 };
  const live = Date.now() - fails.since < 15 * 60 * 1000 ? fails.n : 0;
  if (live >= 5) return json({ error: 'locked', msg: 'Too many wrong PINs: locked for 15 minutes' }, 429);
  if (req.headers.get('x-pin') !== pin) {
    await store.setJSON('lock/fails', { n: live + 1, since: live ? fails.since : Date.now() });
    await wait(1500);
    return json({ error: 'pin' }, 401);
  }
  if (fails.n) await store.delete('lock/fails');
  return null;
}

const cleanId = (v) => (typeof v === 'string' ? v.trim().toUpperCase().replace(/[^A-Z0-9_-]/g, '').slice(0, 40) : '');

export default async (req) => {
  const store = getStore({ name: 'kerma-status', consistency: 'strong' });
  const url = new URL(req.url);
  const path = url.pathname.replace(/\/+$/, '');
  try {
    if (path === '/api/register' && req.method === 'POST') {
      const bad = await checkPin(req, store); if (bad) return bad;
      const key = process.env.STATUS_WRITE_KEY;
      if (!key) return json({ error: 'not-configured', msg: 'STATUS_WRITE_KEY is missing in Netlify' }, 503);
      return json({ key });
    }

    if (path === '/api/status') {
      if (req.method === 'POST') {
        const key = process.env.STATUS_WRITE_KEY;
        if (!key || req.headers.get('x-kerma-key') !== key) { await wait(500); return json({ error: 'key' }, 401); }
        const text = await req.text();
        if (text.length > 200000) return json({ error: 'too big' }, 413);
        const s = JSON.parse(text);
        const id = cleanId(s.key) || cleanId(s.hostname);
        if (!id) return json({ error: 'missing key / hostname' }, 400);
        s.id = id;
        s.received_at = new Date().toISOString();
        await store.setJSON('pc/' + id, s);
        return json({ ok: true, id });
      }
      if (req.method === 'GET') {
        const bad = await checkPin(req, store); if (bad) return bad;
        const { blobs } = await store.list({ prefix: 'pc/' });
        const pcs = (await Promise.all(blobs.map((b) => store.get(b.key, { type: 'json' })))).filter(Boolean);
        return json({ now: new Date().toISOString(), pcs });
      }
      if (req.method === 'DELETE') {
        const bad = await checkPin(req, store); if (bad) return bad;
        const id = cleanId(url.searchParams.get('id'));
        if (!id) return json({ error: 'id' }, 400);
        await store.delete('pc/' + id);
        return json({ ok: true });
      }
    }
    return json({ error: 'not found' }, 404);
  } catch (e) {
    return json({ error: String((e && e.message) || e) }, 500);
  }
};

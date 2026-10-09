// Kerma PC Setup - status of every PC, stored in Netlify Blobs (store "kerma-status").
//   POST   /api/register      (x-pin)        -> { key }  write key for a PC (the setup script asks for the PIN once)
//   POST   /api/status        (x-kerma-key)  -> a PC reports its status (Kerma-Status.ps1, every 5 min)
//   GET    /api/status        (x-pin)        -> { now, pcs: [...] }
//   DELETE /api/status?id=... (x-pin)        -> forget a PC (renamed / retired)
//   POST   /api/log?id=KEY    (x-kerma-key)  -> a PC uploads the log of a setup run (text, last 10 kept per PC)
//   GET    /api/log?id=KEY    (x-pin)        -> { logs: [{ at, size }] } newest first
//   GET    /api/log?id=KEY&at=ISO (x-pin)    -> that log as text
//   POST   /api/command?id=KEY (x-pin)       -> queue an action for that PC, body { action } (only ACTIONS)
//   DELETE /api/command?id=KEY (x-pin)       -> cancel it
// The PCs cannot be reached from here (casino LAN): a queued action goes back in the answer
// to the next POST /api/status of that PC (every 5 min) and is deleted then.
// Environment: STATUS_PIN (people) and STATUS_WRITE_KEY (PCs). Never in the repo: it is public.
// 5 wrong PINs in 15 min lock the PIN for 15 min (blob lock/fails), same as Kerma Tips.
import { getStore } from '@netlify/blobs';

export const config = { path: ['/api/status', '/api/register', '/api/log', '/api/command'] };

const ACTIONS = ['timesync'];

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
        const cmd = await store.get('cmd/' + id, { type: 'json' });
        if (cmd) await store.delete('cmd/' + id);
        return json({ ok: true, id, commands: cmd ? [cmd] : [] });
      }
      if (req.method === 'GET') {
        const bad = await checkPin(req, store); if (bad) return bad;
        const { blobs } = await store.list({ prefix: 'pc/' });
        const pcs = (await Promise.all(blobs.map((b) => store.get(b.key, { type: 'json' })))).filter(Boolean);
        const { blobs: cmds } = await store.list({ prefix: 'cmd/' });
        const pending = {};
        for (const b of cmds) pending[b.key.slice(4)] = await store.get(b.key, { type: 'json' });
        for (const p of pcs) if (pending[p.id]) p.pending = pending[p.id];
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
    if (path === '/api/log') {
      const id = cleanId(url.searchParams.get('id'));
      if (!id) return json({ error: 'id' }, 400);
      const prefix = 'log/' + id + '/';
      if (req.method === 'POST') {
        const key = process.env.STATUS_WRITE_KEY;
        if (!key || req.headers.get('x-kerma-key') !== key) { await wait(500); return json({ error: 'key' }, 401); }
        let text = await req.text();
        const MAX = 1500000;
        if (text.length > MAX) text = '[... start of the log cut: it was ' + text.length + ' characters ...]\n' + text.slice(-MAX);
        const at = new Date().toISOString();
        await store.set(prefix + at, text, { metadata: { size: text.length } });
        const { blobs } = await store.list({ prefix });
        const keys = blobs.map((b) => b.key).sort();
        for (const k of keys.slice(0, Math.max(0, keys.length - 10))) await store.delete(k);
        return json({ ok: true, at });
      }
      if (req.method === 'GET') {
        const bad = await checkPin(req, store); if (bad) return bad;
        const at = url.searchParams.get('at');
        if (at) {
          const text = await store.get(prefix + at.replace(/[^0-9TZ:.\-]/g, ''), { type: 'text' });
          if (text === null) return json({ error: 'not found' }, 404);
          return new Response(text, { headers: { 'content-type': 'text/plain; charset=utf-8', 'cache-control': 'no-store' } });
        }
        const { blobs } = await store.list({ prefix });
        const logs = blobs.map((b) => ({ at: b.key.slice(prefix.length) })).sort((a, b) => (a.at < b.at ? 1 : -1));
        return json({ logs });
      }
    }
    if (path === '/api/command') {
      const bad = await checkPin(req, store); if (bad) return bad;
      const id = cleanId(url.searchParams.get('id'));
      if (!id) return json({ error: 'id' }, 400);
      if (req.method === 'POST') {
        const body = await req.json().catch(() => ({}));
        if (!ACTIONS.includes(body.action)) return json({ error: 'action' }, 400);
        const cmd = { action: body.action, id: Math.random().toString(36).slice(2, 10), at: new Date().toISOString() };
        await store.setJSON('cmd/' + id, cmd);
        return json({ ok: true, pending: cmd });
      }
      if (req.method === 'DELETE') { await store.delete('cmd/' + id); return json({ ok: true }); }
    }
    return json({ error: 'not found' }, 404);
  } catch (e) {
    return json({ error: String((e && e.message) || e) }, 500);
  }
};

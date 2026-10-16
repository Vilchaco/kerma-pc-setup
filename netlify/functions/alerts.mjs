// Kerma PC Setup - avisos del panel de estado (Telegram ahora, Slack despues).
// Cada 5 minutos revisa lo que han reportado los PCs y avisa SOLO cuando algo cambia:
// una vez al fallar y otra al arreglarse. Estado en Blobs (store "kerma-status", alerts/state).
//   Envs: TELEGRAM_BOT_TOKEN + TELEGRAM_CHAT_ID  y/o  SLACK_WEBHOOK_URL. Sin ninguno, no hace nada.
//   POST /api/alerts-test (x-pin) -> manda un mensaje de prueba.
// Que avisa:
//   - una app que debe estar abierta lleva cerrada 10 min (o el vigilante del PC no pudo abrirla)
//   - el vigilante del PC reabrio una app (informativo)
//   - un PC deja de reportar mas de 15 min
//   - el reloj se desvia mas de 2 s
import { getStore } from '@netlify/blobs';
import { notify } from '../shared/notify.mjs';

export const config = { schedule: '*/5 * * * *' };

const PANEL = 'https://kermasetup.netlify.app/estado';
const OFFLINE_MIN = 15;
const APP_MIN = 10;
const BOOT_GRACE_MIN = 3;
const CLOCK_S = 2;

const esc = (s) => String(s ?? '').replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
const hhmm = (iso) => {
  const d = new Date(iso);
  const t = d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit', timeZone: 'America/Monterrey' });
  return Date.now() - d > 12 * 3600000 ? d.toLocaleDateString('es-MX', { day: 'numeric', month: 'short', timeZone: 'America/Monterrey' }) + ' ' + t : t;
};
// PCs que no estan en produccion (env ALERT_IGNORE=BJ03,BJ04): no avisan
const ignored = () => String(process.env.ALERT_IGNORE || '').split(',').map((x) => x.trim().toUpperCase()).filter(Boolean);

// problemas actuales de un PC: { clave: { text, since } }
function problems(p, now) {
  const out = {};
  const name = p.label || p.id;
  const ageMin = (now - new Date(p.received_at)) / 60000;
  if (ageMin > OFFLINE_MIN) {
    out.off = { text: `🔌 <b>${esc(name)}</b>: sin reportar desde las ${hhmm(p.received_at)} (apagado o sin red)`, ok: `✅ <b>${esc(name)}</b>: vuelve a reportar` };
    return out;   // lo demas son datos viejos
  }
  const bootMin = p.windows && p.windows.boot_time ? (new Date(p.received_at) - new Date(p.windows.boot_time)) / 60000 : 99;
  // en mantenimiento (desde el panel) las apps cerradas no avisan
  const maint = p.watchdog_paused_until && new Date(p.watchdog_paused_until) > now;
  if (bootMin >= BOOT_GRACE_MIN && p.user && !maint) {
    for (const a of p.apps || []) {
      if (a.autostart && a.installed && a.running === false) {
        out['app:' + a.name] = { text: `🔴 <b>${esc(name)}</b>: <b>${esc(a.name)}</b> cerrada`, ok: `✅ <b>${esc(name)}</b>: ${esc(a.name)} vuelve a estar abierta`, wait: APP_MIN };
      }
    }
  }
  const off = p.clock && p.clock.offset_s;
  if (typeof off === 'number' && Math.abs(off) > CLOCK_S) {
    out.clock = { text: `🕒 <b>${esc(name)}</b>: reloj desfasado ${off > 0 ? '+' : ''}${off.toFixed(2)} s`, ok: `✅ <b>${esc(name)}</b>: reloj otra vez en hora`, wait: 5 };
  }
  for (const w of p.watchdog_failed || []) {
    out['wdfail:' + w] = { text: `🔴 <b>${esc(name)}</b>: el vigilante NO consigue abrir <b>${esc(w)}</b>`, ok: `✅ <b>${esc(name)}</b>: ${esc(w)} abierta otra vez` };
  }
  return out;
}

export default async (req) => {
  const store = getStore({ name: 'kerma-status', consistency: 'strong' });
  if (!(process.env.TELEGRAM_BOT_TOKEN && process.env.TELEGRAM_CHAT_ID) && !process.env.SLACK_WEBHOOK_URL) return;
  const now = new Date();
  const state = (await store.get('alerts/state', { type: 'json' })) || { open: {}, seen: {}, events: {} };
  const first = !state.started;
  const { blobs } = await store.list({ prefix: 'pc/' });
  const pcs = (await Promise.all(blobs.map((b) => store.get(b.key, { type: 'json' })))).filter(Boolean);
  const msgs = [];
  const current = {};
  const skip = ignored();
  for (const p of pcs) {
    if (skip.includes(String(p.id).toUpperCase())) continue;
    const probs = problems(p, now);
    for (const [k, v] of Object.entries(probs)) {
      const key = p.id + '|' + k;
      current[key] = v;
      if (!state.seen[key]) state.seen[key] = now.toISOString();
      const waited = (now - new Date(state.seen[key])) / 60000;
      if (!state.open[key] && waited >= (v.wait || 0)) {
        state.open[key] = { at: now.toISOString(), ok: v.ok };
        msgs.push(v.text + (v.wait ? ` (desde las ${hhmm(state.seen[key])})` : ''));
      }
    }
    // reaperturas hechas por el vigilante del PC (una vez cada una)
    for (const e of p.watchdog || []) {
      const key = p.id + '|wd|' + e.app + '|' + e.at;
      if (state.events[key]) continue;
      state.events[key] = now.toISOString();
      if (!first) msgs.push(`🛠 <b>${esc(p.label || p.id)}</b>: ${esc(e.app)} estaba cerrada; el vigilante la ha vuelto a abrir (${hhmm(e.at)})`);
    }
  }
  for (const key of Object.keys(state.seen)) if (!current[key]) delete state.seen[key];
  for (const [key, o] of Object.entries(state.open)) {
    if (current[key]) continue;
    msgs.push(o.ok || `✅ ${esc(key)}: resuelto`);
    delete state.open[key];
  }
  // eventos viejos fuera (48 h)
  for (const [k, at] of Object.entries(state.events)) if (now - new Date(at) > 48 * 3600000) delete state.events[k];

  if (first) {
    state.started = now.toISOString();
    const lines = msgs.length ? '\n\nAhora mismo:\n' + msgs.join('\n') : '\n\nAhora mismo todo está bien.';
    await notify(`🔔 <b>Avisos de Kerma activados</b> (${pcs.length} PCs).${lines}\n\n<a href="${PANEL}">Panel de estado</a>`);
  } else if (msgs.length) {
    await notify(msgs.join('\n') + `\n\n<a href="${PANEL}">Panel de estado</a>`);
  }
  await store.setJSON('alerts/state', state);
};

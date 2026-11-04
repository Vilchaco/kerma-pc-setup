// Login of people in the status panel: Google (any @kermagames.com account) -> signed session cookie.
// Same scheme as Kerma Tech Inventory and Kerma Tips (same GOOGLE_CLIENT_ID). The PIN (STATUS_PIN) is
// only for machines now: the setup script registering a new PC, and reading logs from a terminal.
// Environment: GOOGLE_CLIENT_ID, SESSION_SECRET (>= 32 random characters), ALLOWED_DOMAIN (default kermagames.com).
import { createHmac, timingSafeEqual } from 'node:crypto';

const env = (n) => (process.env[n] || '').trim();
export const googleClientId = () => env('GOOGLE_CLIENT_ID') || null;
export const domain = () => (env('ALLOWED_DOMAIN') || 'kermagames.com').toLowerCase();

const COOKIE = 'ks_s';
const DURATION = 30 * 24 * 3600; // 30 days

export class AuthError extends Error {
  constructor(status, msg) { super(msg); this.status = status; }
}

function secret() {
  const s = env('SESSION_SECRET');
  if (s.length < 32) throw new AuthError(503, 'SESSION_SECRET is missing in Netlify (at least 32 random characters)');
  return s;
}
const sign = (part) => createHmac('sha256', secret()).update(part).digest();
const attrs = 'HttpOnly; SameSite=Lax; Path=/; Secure';

export function makeCookie(user) {
  const part = Buffer.from(JSON.stringify({ e: user.email, n: user.name, x: Math.floor(Date.now() / 1000) + DURATION })).toString('base64url');
  return `${COOKIE}=${part}.${sign(part).toString('base64url')}; ${attrs}; Max-Age=${DURATION}`;
}
export const clearCookie = () => `${COOKIE}=; ${attrs}; Max-Age=0`;

// { email, name } of a valid, unexpired session; otherwise null.
export function readSession(req) {
  const pair = (req.headers.get('cookie') || '').split(/;\s*/).find((p) => p.startsWith(COOKIE + '='));
  if (!pair) return null;
  const value = pair.slice(COOKIE.length + 1), i = value.lastIndexOf('.');
  if (i < 1) return null;
  const part = value.slice(0, i);
  const got = Buffer.from(value.slice(i + 1), 'base64url');
  let want;
  try { want = sign(part); } catch { return null; }
  if (got.length !== want.length || !timingSafeEqual(got, want)) return null;
  let d;
  try { d = JSON.parse(Buffer.from(part, 'base64url').toString('utf8')); } catch { return null; }
  if (!d || typeof d.e !== 'string' || !(d.x > Date.now() / 1000)) return null;
  if (!d.e.endsWith('@' + domain())) return null;
  return { email: d.e, name: d.n || d.e };
}

// ---------- Google ID token (RS256, checked with WebCrypto) ----------
const CERTS = 'https://www.googleapis.com/oauth2/v3/certs';
let jwks = { at: 0, keys: null };
async function googleKeys(force = false) {
  const age = Date.now() - jwks.at;
  if (jwks.keys && (force ? age < 60e3 : age < 3600e3)) return jwks.keys;
  let r;
  try { r = await fetch(CERTS); } catch { r = null; }
  if (!r || !r.ok) throw new AuthError(503, 'No se pudo contactar con Google. Inténtalo en un momento.');
  const j = await r.json();
  jwks = { at: Date.now(), keys: Array.isArray(j.keys) ? j.keys : [] };
  return jwks.keys;
}
const b64json = (s) => JSON.parse(Buffer.from(s, 'base64url').toString('utf8'));

export async function verifyGoogleToken(token) {
  const bad = () => new AuthError(403, 'No se pudo comprobar tu cuenta de Google. Vuelve a intentarlo.');
  const clientId = googleClientId();
  if (!clientId) throw new AuthError(503, 'GOOGLE_CLIENT_ID is missing in Netlify');
  if (typeof token !== 'string' || token.length > 8192) throw bad();
  const parts = token.split('.');
  if (parts.length !== 3) throw bad();
  let head, body;
  try { head = b64json(parts[0]); body = b64json(parts[1]); } catch { throw bad(); }
  if (!head || head.alg !== 'RS256' || !head.kid || !body) throw bad();
  let jwk = (await googleKeys(false)).find((k) => k.kid === head.kid);
  if (!jwk) jwk = (await googleKeys(true)).find((k) => k.kid === head.kid);
  if (!jwk || jwk.kty !== 'RSA') throw bad();
  let ok = false;
  try {
    const key = await crypto.subtle.importKey('jwk', { kty: 'RSA', n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
    ok = await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, Buffer.from(parts[2], 'base64url'), new TextEncoder().encode(parts[0] + '.' + parts[1]));
  } catch { ok = false; }
  if (!ok) throw bad();
  if (body.iss !== 'accounts.google.com' && body.iss !== 'https://accounts.google.com') throw bad();
  if (body.aud !== clientId) throw bad();
  if (typeof body.exp !== 'number' || body.exp + 60 < Date.now() / 1000) throw bad();
  const email = String(body.email || '').toLowerCase();
  const dom = domain();
  if (!email || body.email_verified !== true || body.hd !== dom || !email.endsWith('@' + dom)) {
    throw new AuthError(403, `Entra con tu cuenta de Kerma (@${dom}).`);
  }
  return { email, name: body.name || email };
}

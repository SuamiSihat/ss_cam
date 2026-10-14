/**
 * Small in-memory fixed-window rate guards.
 *
 * Used for sign-in, password reset and public-link endpoints. Counters live in process memory,
 * so they reset when the server restarts; the portal runs as a single instance.
 *
 * Sign-in is limited on three axes so that neither a single noisy IP nor a spread-out attack
 * can guess passwords freely, while one person's typos never lock out a colleague:
 *   - per IP + account  (a person mistyping their own password)
 *   - per account       (many IPs guessing one account)
 *   - per IP            (one IP spraying many accounts)
 */

const WINDOW_MS = 15 * 60 * 1000;
const MAX_KEYS = 20000;

class RateBucket {
  constructor({ windowMs = WINDOW_MS, max = 10 } = {}) {
    this.windowMs = windowMs;
    this.max = max;
    this.hits = new Map(); // key -> { count, resetAt }
  }

  _entry(key) {
    const now = Date.now();
    let entry = this.hits.get(key);
    if (!entry || entry.resetAt <= now) {
      if (this.hits.size >= MAX_KEYS) this.prune();
      entry = { count: 0, resetAt: now + this.windowMs };
      this.hits.set(key, entry);
    }
    return entry;
  }

  /** Counts one hit. Returns { ok, retryAfterSec }. */
  consume(key) {
    const entry = this._entry(key);
    entry.count += 1;
    return {
      ok: entry.count <= this.max,
      retryAfterSec: Math.max(1, Math.ceil((entry.resetAt - Date.now()) / 1000))
    };
  }

  /** Reads the current state without counting a hit. */
  peek(key) {
    const entry = this.hits.get(key);
    if (!entry || entry.resetAt <= Date.now()) return { ok: true, retryAfterSec: 0 };
    return { ok: entry.count < this.max, retryAfterSec: Math.max(1, Math.ceil((entry.resetAt - Date.now()) / 1000)) };
  }

  reset(key) {
    this.hits.delete(key);
  }

  resetWhere(predicate) {
    for (const key of this.hits.keys()) {
      if (predicate(key)) this.hits.delete(key);
    }
  }

  prune() {
    const now = Date.now();
    for (const [key, entry] of this.hits) {
      if (entry.resetAt <= now) this.hits.delete(key);
    }
    // Still full (sustained flood of unique keys): drop the oldest half rather than grow without bound.
    if (this.hits.size >= MAX_KEYS) {
      let i = 0;
      for (const key of this.hits.keys()) {
        if (i++ >= MAX_KEYS / 2) break;
        this.hits.delete(key);
      }
    }
  }
}

function isEnforced() {
  // The automated test suite signs in many times from one address; opt back in per test.
  return process.env.NODE_ENV !== 'test' || process.env.RATE_GUARD_ENFORCE === '1';
}

const signInPerIpAccount = new RateBucket({ max: 10 });
const signInPerAccount = new RateBucket({ max: 40 });
const signInPerIp = new RateBucket({ max: 30 });

const LoginGuard = {
  accountKey(account) {
    return String(account || 'anonymous').trim().toLowerCase().slice(0, 100);
  },

  /** Returns { blocked, retryAfterSec } without counting an attempt. */
  check(ip, account) {
    if (!isEnforced()) return { blocked: false, retryAfterSec: 0 };
    const acct = this.accountKey(account);
    const states = [
      signInPerIpAccount.peek(`${ip}|${acct}`),
      signInPerAccount.peek(acct),
      signInPerIp.peek(String(ip))
    ];
    const blocked = states.find(s => !s.ok);
    return blocked ? { blocked: true, retryAfterSec: blocked.retryAfterSec } : { blocked: false, retryAfterSec: 0 };
  },

  recordFailure(ip, account) {
    if (!isEnforced()) return;
    const acct = this.accountKey(account);
    signInPerIpAccount.consume(`${ip}|${acct}`);
    signInPerAccount.consume(acct);
    signInPerIp.consume(String(ip));
  },

  recordSuccess(ip, account) {
    const acct = this.accountKey(account);
    signInPerIpAccount.reset(`${ip}|${acct}`);
  },

  /** Admin unlock: clears every counter that mentions the account. */
  clearAccount(account) {
    const acct = this.accountKey(account);
    signInPerAccount.reset(acct);
    signInPerIpAccount.resetWhere(key => key.endsWith(`|${acct}`));
  }
};

/** Express middleware factory for simple per-IP (plus optional extra key) limits on public endpoints. */
function limitBy({ windowMs = WINDOW_MS, max = 10, message, keyFn, includeIp = true } = {}) {
  const bucket = new RateBucket({ windowMs, max });
  return (req, res, next) => {
    if (!isEnforced()) return next();
    const extra = keyFn ? keyFn(req) : '';
    const result = bucket.consume(`${includeIp ? req.ip : ''}|${extra}`);
    if (!result.ok) {
      res.setHeader('Retry-After', String(result.retryAfterSec));
      return res.status(429).json({ error: message || 'Too many attempts. Please wait a few minutes and try again.' });
    }
    next();
  };
}

module.exports = { RateBucket, LoginGuard, limitBy };

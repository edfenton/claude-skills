type Bucket = { tokens: number; lastRefillMs: number };

export type RateLimitConfig = {
  capacity: number;
  refillPerSecond: number;
};

const buckets = new Map<string, Bucket>();

export function rateLimit(
  key: string,
  cfg: RateLimitConfig,
): { allowed: boolean; remaining: number } {
  const now = Date.now();
  const bucket = buckets.get(key) ?? {
    tokens: cfg.capacity,
    lastRefillMs: now,
  };

  const elapsedSec = Math.max(0, (now - bucket.lastRefillMs) / 1000);
  const refill = elapsedSec * cfg.refillPerSecond;
  bucket.tokens = Math.min(cfg.capacity, bucket.tokens + refill);
  bucket.lastRefillMs = now;

  if (bucket.tokens < 1) {
    buckets.set(key, bucket);
    return { allowed: false, remaining: 0 };
  }

  bucket.tokens -= 1;
  buckets.set(key, bucket);
  return { allowed: true, remaining: Math.floor(bucket.tokens) };
}

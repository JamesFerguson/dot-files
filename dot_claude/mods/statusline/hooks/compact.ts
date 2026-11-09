// Compact an idle session whose cache is about to go cold over a big context: the compaction reads the
// context at the cache-read price, where the first reply after the cache goes cold rewrites all of it at
// the cache-write price. Compaction takes about a minute, but only its first request has to go out before
// the cache expires, so the lead is short. A 1-hour cache gets more, being cheap against the hour.
export const COMPACT_TOKENS = 200_000
export const leadMs = (ttl: number) => (ttl >= 3600 ? 90 : 30) * 1000
// A timer can fire a little early; aim this far inside the window.
const TIMER_SLACK_MS = 1000

// statusline.rb's reading of the transcript: when the last main-thread request went out, the TTL of the
// last cache write and when it runs out (epoch seconds), and the context the reply was answered over.
export type Cache = { sent_at: number, ttl: number, expires_at: number, tokens: number | null }

export type Session = {
  nowMs: number
  limit: number
  turnRunning: boolean
  // The request a compaction was last tried for: each one gets one try.
  compactedFor?: number
}

// Whether the session would compact once the cache is close enough to going cold.
export const wantsCompact = (cache: Cache | undefined, { limit, compactedFor }: Pick<Session, 'limit' | 'compactedFor'>): cache is Cache =>
  !!cache && limit > 0 && (cache.tokens ?? 0) > limit && compactedFor !== cache.sent_at

export const shouldCompact = (cache: Cache | undefined, session: Session) => {
  if (!wantsCompact(cache, session) || session.turnRunning) return false
  const left = cache.expires_at * 1000 - session.nowMs
  return left > 0 && left <= leadMs(cache.ttl)
}

// When a timer should fire to compact: just inside the lead before the cache goes cold.
export const compactAtMs = (cache: Cache) => cache.expires_at * 1000 - leadMs(cache.ttl) + TIMER_SLACK_MS

export const compactLimit = (option: unknown) => {
  const limit = Number(option ?? COMPACT_TOKENS)
  return Number.isFinite(limit) ? limit : COMPACT_TOKENS
}

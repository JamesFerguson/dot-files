// Compact an idle session whose cache is about to go cold over a big context: the compaction reads the
// context at the cache-read price, where the first reply after the cache goes cold rewrites all of it at
// the cache-write price. Compaction takes about a minute, but only its first request needs the cache.
export const COMPACT_LEAD_MS = 90 * 1000
export const COMPACT_TOKENS = 200_000

// statusline.rb's reading of the transcript: the last main-thread reply, when its cache goes cold (both
// epoch seconds), and the context it was answered over.
export type Cache = { last_reply_at: number, expires_at: number, tokens: number | null }

export type Session = {
  nowMs: number
  limit: number
  turnRunning: boolean
  // The reply a compaction was last tried for: each reply gets one try.
  compactedFor?: number
}

export const shouldCompact = (cache: Cache | undefined, { nowMs, limit, turnRunning, compactedFor }: Session) => {
  if (!cache || limit <= 0 || turnRunning || (cache.tokens ?? 0) <= limit) return false
  if (compactedFor === cache.last_reply_at) return false
  const left = cache.expires_at * 1000 - nowMs
  return left > 0 && left <= COMPACT_LEAD_MS
}

export const compactLimit = (option: unknown) => {
  const limit = Number(option ?? COMPACT_TOKENS)
  return Number.isFinite(limit) ? limit : COMPACT_TOKENS
}

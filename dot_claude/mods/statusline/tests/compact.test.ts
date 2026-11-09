import { expect, test } from 'claude-code/testing'

import { compactAtMs, compactLimit, shouldCompact, wantsCompact } from '../hooks/compact'

const NOW_MS = 1_794_200_000_000
const expiringIn = (seconds: number, { ttl = 3600, tokens = 250_000 as number | null } = {}) =>
  ({ sent_at: NOW_MS / 1000 - ttl + seconds, ttl, expires_at: NOW_MS / 1000 + seconds, tokens })
const idle = { nowMs: NOW_MS, limit: 200_000, turnRunning: false }

test('an idle session over the limit compacts in the last 90 seconds of a 1-hour cache', () => {
  expect(shouldCompact(expiringIn(60), idle)).toBe(true)
  expect(shouldCompact(expiringIn(90), idle)).toBe(true)
  expect(shouldCompact(expiringIn(120), idle)).toBe(false)
  expect(shouldCompact(expiringIn(0), idle)).toBe(false)
  expect(shouldCompact(expiringIn(-30), idle)).toBe(false)
})

test('a 5-minute cache compacts in its last 30 seconds', () => {
  expect(shouldCompact(expiringIn(30, { ttl: 300 }), idle)).toBe(true)
  expect(shouldCompact(expiringIn(5, { ttl: 300 }), idle)).toBe(true)
  expect(shouldCompact(expiringIn(40, { ttl: 300 }), idle)).toBe(false)
})

test('the timer fires just inside the window', () => {
  for (const ttl of [300, 3600]) {
    const cache = expiringIn(600, { ttl })
    expect(shouldCompact(cache, { ...idle, nowMs: compactAtMs(cache) })).toBe(true)
    expect(shouldCompact(cache, { ...idle, nowMs: compactAtMs(cache) - 1001 })).toBe(false)
  }
})

test('a context at or under the limit, or no limit, never compacts', () => {
  expect(shouldCompact(expiringIn(60, { tokens: 200_000 }), idle)).toBe(false)
  expect(shouldCompact(expiringIn(60, { tokens: null }), idle)).toBe(false)
  expect(shouldCompact(expiringIn(60), { ...idle, limit: 0 })).toBe(false)
  expect(wantsCompact(expiringIn(600, { tokens: 200_000 }), idle)).toBe(false)
})

test('a running turn, or a request already tried, never compacts', () => {
  expect(shouldCompact(expiringIn(60), { ...idle, turnRunning: true })).toBe(false)
  const cache = expiringIn(60)
  expect(shouldCompact(cache, { ...idle, compactedFor: cache.sent_at })).toBe(false)
  expect(wantsCompact(cache, { ...idle, compactedFor: cache.sent_at })).toBe(false)
  expect(shouldCompact(undefined, idle)).toBe(false)
})

test('the limit defaults to 200k', () => {
  expect(compactLimit(undefined)).toBe(200_000)
  expect(compactLimit('nonsense')).toBe(200_000)
  expect(compactLimit(0)).toBe(0)
  expect(compactLimit(300_000)).toBe(300_000)
})

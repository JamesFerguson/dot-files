import { expect, test } from 'claude-code/testing'

import { compactLimit, shouldCompact } from '../hooks/compact'

const NOW_MS = 1_794_200_000_000
const expiringIn = (seconds: number, tokens: number | null = 250_000) =>
  ({ last_reply_at: NOW_MS / 1000 - 3600 + seconds, expires_at: NOW_MS / 1000 + seconds, tokens })
const idle = { nowMs: NOW_MS, limit: 200_000, turnRunning: false }

test('an idle session over the limit compacts in the last 90 seconds of its cache', () => {
  expect(shouldCompact(expiringIn(60), idle)).toBe(true)
  expect(shouldCompact(expiringIn(90), idle)).toBe(true)
  expect(shouldCompact(expiringIn(120), idle)).toBe(false)
  expect(shouldCompact(expiringIn(0), idle)).toBe(false)
  expect(shouldCompact(expiringIn(-30), idle)).toBe(false)
})

test('a context at or under the limit, or no limit, never compacts', () => {
  expect(shouldCompact(expiringIn(60, 200_000), idle)).toBe(false)
  expect(shouldCompact(expiringIn(60, null), idle)).toBe(false)
  expect(shouldCompact(expiringIn(60), { ...idle, limit: 0 })).toBe(false)
})

test('a running turn, or a reply already tried, never compacts', () => {
  expect(shouldCompact(expiringIn(60), { ...idle, turnRunning: true })).toBe(false)
  const cache = expiringIn(60)
  expect(shouldCompact(cache, { ...idle, compactedFor: cache.last_reply_at })).toBe(false)
  expect(shouldCompact(undefined, idle)).toBe(false)
})

test('the limit defaults to 200k', () => {
  expect(compactLimit(undefined)).toBe(200_000)
  expect(compactLimit('nonsense')).toBe(200_000)
  expect(compactLimit(0)).toBe(0)
  expect(compactLimit(300_000)).toBe(300_000)
})

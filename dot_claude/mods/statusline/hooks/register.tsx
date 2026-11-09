import { atom, read, update } from 'claude-code'
import type { EngineInterface, PluginOptions, Register, SessionRateLimit } from 'claude-code'

import type { Run } from '../types'
import { parseAnsi } from './ansi'
import { type Cache, compactAtMs, compactLimit, shouldCompact, wantsCompact } from './compact'

// bin/statusline.rb draws the line from the JSON a status line command gets; this mod feeds it that
// JSON on a timer, so the countdowns keep moving while nobody types.
const TICK_MS = 20 * 1000
// The account-wide figures /usage shows; they change slowly, so they are fetched less often.
const USAGE_MS = 5 * 60 * 1000
const USAGE_URL = 'https://api.anthropic.com/api/oauth/usage'
const line = atom({ plugin: 'statusline', key: 'line' } as const, null as Run[] | null)

let drawing = false
let reported = false
let turnRunning = false
let compactedFor: number | undefined
let armed: { sentAt: number, timer: ReturnType<EngineInterface['clock']['after']> } | undefined
let ticking: unknown
let polling: unknown
let options: PluginOptions = {}
let creditsFailed = false
let credits: { used_minor: number, limit_minor: number, exponent: number, currency: string, fetched_at: number } | undefined

const window = (limits: readonly SessionRateLimit[], kind: string) => {
  const limit = limits.find(one => one.kind === kind)
  if (!limit) return undefined
  return {
    used_percentage: limit.percentUsed,
    resets_at: limit.resetsAt ? Math.floor(Date.parse(limit.resetsAt) / 1000) : undefined,
  }
}

// Usage credits (the extra-usage spend cap) from the endpoint /usage reads, with the session's own login.
// The endpoint is rate-limited, so the last answer is kept in the store: every session and every reload
// shows it at once, and only one fetch per USAGE_MS goes out between them. A failed fetch keeps it.
const fetchCredits = async ($: EngineInterface) => {
  const [saved, now] = await Promise.all([$.store.get('credits') as Promise<typeof credits>, $.clock.now()])
  if (saved) credits = saved
  if (saved && now - saved.fetched_at < USAGE_MS) return void redraw($)

  const auth = (await $.session.authorize())?.handle
  const response = await $.http.fetch(USAGE_URL, { auth, headers: { 'anthropic-beta': 'oauth-2025-04-20' } })
  if (!response.ok) {
    if (!creditsFailed) $.ui.log(`statusline: the usage endpoint answered ${response.status}; showing the last credits it gave`)
    creditsFailed = true
    return void redraw($)
  }
  const spend = JSON.parse(response.text)?.spend
  if (!spend?.enabled || !spend.used || !spend.limit) {
    credits = undefined
    await $.store.delete('credits')
    return void redraw($)
  }
  credits = {
    used_minor: spend.used.amount_minor,
    limit_minor: spend.limit.amount_minor,
    exponent: spend.used.exponent,
    currency: spend.used.currency,
    fetched_at: now,
  }
  await $.store.set('credits', credits)
  void redraw($)
}

const pollCredits = ($: EngineInterface) => {
  polling ??= $.clock.every(USAGE_MS, () => void fetchCredits($).catch(() => undefined))
  void fetchCredits($).catch(() => undefined)
}

const statusInput = async ($: EngineInterface) => {
  const [usage, cwd, model, id, version, rows] = await Promise.all([
    $.session.usage(), $.session.cwd(), $.session.model(), $.session.id(), $.session.version(), $.config.list(),
  ])
  // The /config effort row when there is one; statusline.rb falls back to settings.json.
  const effortRow = rows.find(row => /effort/i.test(row.key))
  const effort = typeof effortRow?.value === 'string' ? effortRow.value : undefined
  return {
    session_id: id,
    model: { id: model },
    effort: effort ? { level: effort } : undefined,
    context_window: {
      used_percentage: usage.context.percent,
      total_input_tokens: usage.context.tokens,
      context_window_size: usage.context.window,
    },
    workspace: { current_dir: cwd },
    rate_limits: { five_hour: window(usage.rateLimits, 'five_hour'), seven_day: window(usage.rateLimits, 'seven_day') },
    cost: usage.cost ? { total_cost_usd: usage.cost.usd } : undefined,
    version: version.version,
    usage_credits: credits,
    options,
    format: 'json',
  }
}

const failed = (reason: string): Run[] => [{ text: `statusline: ${reason}`, fg: 'red' }]

// The mod gets no shell PATH, so no version manager is active: find its ruby shim, and run from bin/,
// whose .tool-versions and .ruby-version pick the Ruby. Homebrew Ruby is the fallback.
const rubyCandidates = async ($: EngineInterface) => {
  const [home, mise, asdf, rbenv] = await Promise.all([
    $.env.get('HOME'), $.env.get('MISE_DATA_DIR'), $.env.get('ASDF_DATA_DIR'), $.env.get('RBENV_ROOT'),
  ])
  return [
    `${mise ?? `${home}/.local/share/mise`}/shims/ruby`,
    `${asdf ?? `${home}/.asdf`}/shims/ruby`,
    `${rbenv ?? `${home}/.rbenv`}/shims/ruby`,
    '/opt/homebrew/opt/ruby/bin/ruby',
    '/usr/local/opt/ruby/bin/ruby',
  ]
}

let ruby: string | undefined

const findRuby = async ($: EngineInterface) => {
  for (const path of await rubyCandidates($)) if (await $.fs.exists(path)) return path
  return undefined
}

type Drawn = { runs: Run[], cache?: Cache }

const run = async ($: EngineInterface): Promise<Drawn> => {
  ruby ??= await findRuby($)
  if (!ruby) return { runs: failed('no Ruby found (looked for mise, asdf and rbenv shims, and Homebrew Ruby)') }
  const [home, path] = await Promise.all([$.env.get('HOME'), $.env.get('PATH')])
  const { exitCode, stdout, stderr } = await $.process.run([ruby, `${$.plugin.root}/bin/statusline.rb`], {
    stdin: JSON.stringify(await statusInput($)),
    cwd: `${$.plugin.root}/bin`,
    // Some shims call their manager by name (asdf exec), so its usual homes go on the PATH.
    env: { PATH: [`${home}/.asdf/bin`, `${home}/.local/bin`, '/opt/homebrew/bin', '/usr/local/bin', path].filter(Boolean).join(':') },
    timeoutMs: 10_000,
  })
  if (exitCode !== 0) return { runs: failed(`statusline.rb exited ${exitCode}: ${stderr.trim().slice(0, 200)}`) }
  const { line, cache } = JSON.parse(stdout) as { line: string, cache: Cache | null }
  return { runs: parseAnsi(line.trimEnd()), cache: cache ?? undefined }
}

// Compacts once the cache is close enough to going cold, or arms a timer for then: the 20-second tick
// alone could land too late in a 30-second lead. The timer redraws, so it acts on a fresh reading.
const scheduleCompact = async ($: EngineInterface, cache: Cache | undefined) => {
  const limit = compactLimit(options.auto_compact_tokens)
  if (!wantsCompact(cache, { limit, compactedFor })) return disarm()

  const nowMs = await $.clock.now()
  if (shouldCompact(cache, { nowMs, limit, turnRunning, compactedFor })) return compact($, cache)
  if (armed?.sentAt === cache.sent_at) return

  disarm()
  const waitMs = compactAtMs(cache) - nowMs
  if (waitMs > 0) armed = { sentAt: cache.sent_at, timer: $.clock.after(waitMs, () => { armed = undefined; void redraw($) }) }
}

const disarm = () => {
  armed?.timer.cancel()
  armed = undefined
}

// A compaction that fails or is vetoed isn't tried again until the next request.
const compact = async ($: EngineInterface, cache: Cache) => {
  compactedFor = cache.sent_at
  const size = `${Math.round((cache.tokens ?? 0) / 1000)}k`
  $.ui.toast(`statusline: compacting ${size} of context before the cache goes cold`)
  const result = await $.session.compact().catch((error: unknown) => ({ skip: String(error).slice(0, 200) }))
  if ('skip' in result && result.skip) {
    $.ui.log(`statusline: didn't compact ${size} of context before the cache went cold: ${result.skip}`)
  } else {
    const after = 'tokensAfter' in result && result.tokensAfter ? ` to ${Math.round(result.tokensAfter / 1000)}k` : ''
    $.ui.log(`statusline: compacted ${size} of context${after} before the cache went cold`)
  }
}

// A failure shows in the band, and once in the transcript, rather than leaving the band empty.
const redraw = async ($: EngineInterface) => {
  if (drawing) return
  drawing = true
  ticking ??= $.clock.every(TICK_MS, () => void redraw($))
  try {
    const { runs, cache } = await run($).catch((error: unknown): Drawn => ({ runs: failed(String(error).slice(0, 200)) }))
    const first = runs[0]
    if (first?.text.startsWith('statusline: ') && !reported) {
      reported = true
      $.ui.log(first.text)
    }
    await update($, line, () => runs)
    void scheduleCompact($, cache).catch(() => undefined)
  } finally {
    drawing = false
  }
}

export const register: Register = (on, given) => {
  options = given

  on('session.start', async ($, e, next) => {
    const result = await next(e)
    if (options.credits !== false) pollCredits($)
    void redraw($)
    return result
  })

  // The main loop's turns alone: a compaction can't start while one runs.
  on('turn.start', async ($, e, next) => {
    if (e.agentId === undefined) turnRunning = true
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    if (e.agentId === undefined) turnRunning = false
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    void redraw($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // Other mods' bands, and the engine's own, go under the line rather than being replaced by it.
    const below = await next(e)
    const runs = await read($, line)
    if (e.props.hasSurvey || !runs) return below

    const { Box, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column">
        <Text>
          {runs.map(run => (
            <Text color={run.fg} backgroundColor={run.bg} bold={run.bold}>
              {run.text}
            </Text>
          ))}
        </Text>
        {below}
      </Box>
    )
  })
}

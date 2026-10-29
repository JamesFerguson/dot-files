import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, SessionRateLimit } from 'claude-code'

import type { Run } from '../types'
import { parseAnsi } from './ansi'

// ~/.claude/statusline.rb draws the line, as it does for the status line command; this mod feeds it
// the same JSON on a timer, so the countdowns keep moving while nobody types.
const TICK_MS = 20 * 1000
const line = atom({ plugin: 'statusline', key: 'line' } as const, null as Run[] | null)

let drawing = false
let reported = false
let ticking: unknown

const window = (limits: readonly SessionRateLimit[], kind: string) => {
  const limit = limits.find(one => one.kind === kind)
  if (!limit) return undefined
  return {
    used_percentage: limit.percentUsed,
    resets_at: limit.resetsAt ? Math.floor(Date.parse(limit.resetsAt) / 1000) : undefined,
  }
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
  }
}

const failed = (reason: string): Run[] => [{ text: `statusline: ${reason}`, fg: 'red' }]

const run = async ($: EngineInterface): Promise<Run[]> => {
  const home = await $.env.get('HOME')
  const { exitCode, stdout, stderr } = await $.process.run([`${home}/.local/share/mise/shims/ruby`, `${home}/.claude/statusline.rb`], {
    stdin: JSON.stringify(await statusInput($)),
    // The mod gets no mise on its PATH, and a repo may pin an older Ruby; the global one is 4.0.
    cwd: home,
    timeoutMs: 10_000,
  })
  return exitCode === 0 ? parseAnsi(stdout.trimEnd()) : failed(`statusline.rb exited ${exitCode}: ${stderr.trim().slice(0, 200)}`)
}

// A failure shows in the band, and once in the transcript, rather than leaving the band empty.
const redraw = async ($: EngineInterface) => {
  if (drawing) return
  drawing = true
  ticking ??= $.clock.every(TICK_MS, () => void redraw($))
  try {
    const runs = await run($).catch((error: unknown) => failed(String(error).slice(0, 200)))
    const first = runs[0]
    if (first?.text.startsWith('statusline: ') && !reported) {
      reported = true
      $.ui.log(first.text)
    }
    await update($, line, () => runs)
  } finally {
    drawing = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    void redraw($)
    return result
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    void redraw($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const runs = await read($, line)
    if (e.props.hasSurvey || !runs) return next(e)

    const { Text } = $.ui.resolve(e)
    return (
      <Text>
        {runs.map(run => (
          <Text color={run.fg} backgroundColor={run.bg} bold={run.bold}>
            {run.text}
          </Text>
        ))}
      </Text>
    )
  })
}

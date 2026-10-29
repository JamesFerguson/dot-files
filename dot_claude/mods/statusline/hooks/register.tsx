import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, SessionRateLimit } from 'claude-code'

import type { Run } from '../types'
import { parseAnsi } from './ansi'

// ~/.claude/statusline.rb draws the line, as it does for the status line command; this mod feeds it
// the same JSON on a timer, so the countdowns keep moving while nobody types.
const TICK_MS = 20 * 1000
const line = atom({ plugin: 'statusline', key: 'line' } as const, null as Run[] | null)

let drawing = false

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

const redraw = async ($: EngineInterface) => {
  if (drawing) return
  drawing = true
  try {
    const home = await $.env.get('HOME')
    const { exitCode, stdout, stderr } = await $.process.run(['ruby', `${home}/.claude/statusline.rb`], {
      stdin: JSON.stringify(await statusInput($)),
      timeoutMs: 10_000,
    })
    if (exitCode !== 0) {
      $.ui.log(`statusline: statusline.rb exited ${exitCode}: ${stderr.slice(0, 200)}`, { to: 'debug' })
      return
    }
    await update($, line, () => parseAnsi(stdout.trimEnd()))
  } finally {
    drawing = false
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    void redraw($)
    $.clock.every(TICK_MS, () => void redraw($))
    return result
  })

  on('session.measure', async ($, e, next) => {
    const result = await next(e)
    void redraw($)
    return result
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
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

import type { Run } from '../types'

const BASIC = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']

const hex = (r: number, g: number, b: number) => '#' + [r, g, b].map(n => n.toString(16).padStart(2, '0')).join('')

type Style = Omit<Run, 'text'>

// Applies one SGR sequence's parameters (the numbers in ESC[...m) to the current style.
const apply = (style: Style, params: number[]): Style => {
  let next = { ...style }
  for (let i = 0; i < params.length; i++) {
    const p = params[i] ?? 0
    if (p === 0) next = {}
    else if (p === 1) next.bold = true
    else if (p >= 30 && p <= 37) next.fg = BASIC[p - 30]
    else if (p >= 90 && p <= 97) next.fg = BASIC[p - 90] + 'Bright'
    else if (p >= 40 && p <= 47) next.bg = BASIC[p - 40]
    else if ((p === 38 || p === 48) && params[i + 1] === 2) {
      const colour = hex(params[i + 2] ?? 0, params[i + 3] ?? 0, params[i + 4] ?? 0)
      if (p === 38) next.fg = colour
      else next.bg = colour
      i += 4
    }
  }
  return next
}

const sameStyle = (a: Style, b: Style) => a.fg === b.fg && a.bg === b.bg && !!a.bold === !!b.bold

export const parseAnsi = (line: string): Run[] => {
  const runs: Run[] = []
  let style: Style = {}
  for (const part of line.split(/(\x1b\[[0-9;]*m)/)) {
    const sgr = /^\x1b\[([0-9;]*)m$/.exec(part)
    if (sgr) {
      const codes = sgr[1] ?? ''
      style = apply(style, codes === '' ? [0] : codes.split(';').map(Number))
      continue
    }
    if (part === '') continue
    const last = runs[runs.length - 1]
    if (last && sameStyle(last, style)) last.text += part
    else runs.push({ text: part, ...style })
  }
  return runs
}

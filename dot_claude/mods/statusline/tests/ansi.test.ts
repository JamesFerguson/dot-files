import { expect, test } from 'claude-code/testing'

import { parseAnsi } from '../hooks/ansi'

test('truecolour and basic colours become runs, and reset ends them', () => {
  expect(parseAnsi('\x1b[38;2;0;200;80m█\x1b[0m 40%')).toEqual([
    { text: '█', fg: '#00c850' },
    { text: ' 40%' },
  ])
  expect(parseAnsi('\x1b[33m[\x1b[1mgw\x1b[0m')).toEqual([
    { text: '[', fg: 'yellow' },
    { text: 'gw', fg: 'yellow', bold: true },
  ])
})

test('the alert badges keep their background', () => {
  expect(parseAnsi('\x1b[1;97;41m ⚠️ Opus \x1b[0m')).toEqual([
    { text: ' ⚠️ Opus ', fg: 'whiteBright', bg: 'red', bold: true },
  ])
  expect(parseAnsi('\x1b[1;30;48;2;255;140;0m low \x1b[0m')).toEqual([
    { text: ' low ', fg: 'black', bg: '#ff8c00', bold: true },
  ])
})

test('adjacent runs in the same style merge', () => {
  expect(parseAnsi('\x1b[32ma\x1b[32mb')).toEqual([{ text: 'ab', fg: 'green' }])
})

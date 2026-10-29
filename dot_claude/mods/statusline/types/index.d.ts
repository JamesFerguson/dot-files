export type Run = { text: string; fg?: string; bg?: string; bold?: boolean }

declare module 'claude-code' {
  interface PluginState {
    statusline: { line: Run[] | null }
  }
}

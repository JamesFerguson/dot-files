#!/bin/zsh -f
# Records Claude Code's current default model for the status line, which flags sessions running
# anything else. A fresh headless session with no setting sources can't be overridden by a
# settings `model`, a resumed conversation or /model, so the model it starts on is the default.
# Also records the models on offer, so the status line can name an advisor set by alias in
# settings.json. The prompt is /cost, which Claude Code answers itself, so no request goes to the
# API and the probe uses no tokens. statusline.rb starts it in the background when the record is
# over ten minutes old (default_model.rb). Leaves the existing file alone on any failure.

export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/bin:/bin"
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
unset ANTHROPIC_MODEL
cd "$HOME" || exit 1

OUT="${STATUSLINE_DEFAULT_MODEL_CACHE:-$HOME/.claude/statusline-default-model.json}"

init=$(timeout 90 claude -p --output-format stream-json --verbose --setting-sources '' \
  --no-session-persistence /cost 2>/dev/null | head -1)
model=$(jq -r 'select(.subtype == "init") | .model // empty' <<<"$init" 2>/dev/null)
version=$(jq -r '.claude_code_version // empty' <<<"$init" 2>/dev/null)
if [[ -z $model || -z $version ]]; then
  echo "$(date '+%F %T') no init event from claude; keeping $OUT"
  exit 1
fi

# Model ids Claude Code offers beyond the default, e.g. Fable when it isn't the default.
offered=$(jq -c '[.additionalModelOptionsCache[]?.value]' ~/.claude.json 2>/dev/null || echo '[]')

tmp="$OUT.tmp.$$"
jq -n --arg v "$version" --arg m "$model" --argjson offered "$offered" \
  '{version: $v, default_id: $m, offered: $offered, checked_at: (now | todate)}' >"$tmp" &&
  mv "$tmp" "$OUT"
echo "$(date '+%F %T') default $model on Claude Code $version"

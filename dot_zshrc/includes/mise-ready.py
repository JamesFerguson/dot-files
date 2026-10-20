#!/usr/bin/env python3
"""mise-ready.py -- the mise-side twin of brew_refresh.zsh's cooldown.

Picks, for each outdated mise tool, the newest version that has *soaked* for the
cooldown, so an upgrade lands after N days of other people hitting its bugs rather
than on release day. mise can do what brew can't here: it installs a *specific*
older version, so you ride the newest soaked version while newer ones keep cooling
-- brew only ever installs latest.

Per tool, from `mise outdated --bump --json` (current + bump, the ceiling) and
`mise ls-remote --json <tool>` (per-version `created_at`), the chosen version is the
newest V that clears ALL of:

  * current < V <= bump                 (ahead of what you run, no past the bump track)
  * same major as current               (patch/minor only; a real major is a manual call)
  * same build variant as current       (python stays on its `t` build, elixir on -otp-29)
  * not a prerelease
  * released at least COOLDOWN days ago  (soaked)

If nothing in range has soaked, the tool stays on current. The status says *why*:
  READY <v>  -- install it;  COOLING -- dated but too fresh;  UNDATED -- mise's
  registry has no dates for the in-range versions (held, needs a manual call -- ruby
  hits this); HELD -- the bump crosses a major or a build variant (manual call);
  SKIP -- listed in MISE_COOLDOWN_SKIP.

stdout: `<tool>\t<version>` per READY tool (feed straight to `mise use`).
stderr: one decision line per outdated tool.
env:    MISE_COOLDOWN_DAYS (default 10).
        MISE_COOLDOWN_SKIP  space/comma-separated tools to leave entirely manual.
"""
import sys, os, json, re, subprocess
from datetime import datetime, timezone

COOLDOWN = int(os.environ.get('MISE_COOLDOWN_DAYS', '10'))
SKIP = set(re.split(r'[,\s]+', os.environ.get('MISE_COOLDOWN_SKIP', '').strip())) - {''}
NOW = datetime.now(timezone.utc)
PREWORDS = ('rc', 'alpha', 'beta', 'preview', 'pre', 'dev', 'nightly',
            'snapshot', 'canary', 'milestone', 'eap')


def is_prerelease(v):
    # a prerelease tags the version after a '-'/'+' separator (1.2.0-rc1, 4.1.0-preview1);
    # a bare suffix like python's 3.14.7t or elixir's 1.20.3-otp-29 is NOT one.
    for seg in re.split(r'[-+]', v.lower())[1:]:
        if any(seg.startswith(w) for w in PREWORDS):
            return True
    return False


def vkey(v):
    # natural-order key: numeric runs compare as ints, alpha runs as strings, all
    # elements are same-shape 3-tuples so lists of them compare without type errors.
    out = []
    for tok in re.findall(r'\d+|[A-Za-z]+', v):
        out.append((1, int(tok), '') if tok.isdigit() else (0, 0, tok.lower()))
    return out


def major(v):
    m = re.match(r'(\d+)', v)
    return m.group(1) if m else ''


def variant(v):
    # everything after the leading dotted-number core: '' for 26.7.0, 't' for 3.14.7t,
    # '-otp-29' for 1.20.3-otp-29. A change here is a different build, not an upgrade.
    return re.sub(r'^[0-9.]+', '', v)


def parse_ts(s):
    if not s:
        return None
    s = re.sub(r'\.\d+', '', s).replace('Z', '+00:00')
    try:
        return datetime.fromisoformat(s)
    except Exception:
        return None


def mise_json(args):
    try:
        r = subprocess.run(['mise', *args], capture_output=True, text=True, timeout=60)
        out = r.stdout.strip()
        return json.loads(out) if out else None
    except Exception:
        return None


def choose(current, bump, remote):
    """Return (version|None, detail, status). status in ready/cooling/undated/held."""
    ck, bk = vkey(current), vkey(bump)
    cmaj, cvar = major(current), variant(current)
    cands = []  # (vkey, version, timestamp|None) within range, same major+variant, release
    for entry in remote:
        v = entry.get('version', '')
        if not v or is_prerelease(v):
            continue
        if major(v) != cmaj or variant(v) != cvar:
            continue
        vk = vkey(v)
        if not (ck < vk <= bk):
            continue
        cands.append((vk, v, parse_ts(entry.get('created_at'))))
    if not cands:
        # bump exists but nothing in range survives the major/variant guard
        if major(bump) != cmaj:
            return None, f'bump {bump} crosses major {cmaj}->{major(bump)}', 'held'
        if variant(bump) != cvar:
            return None, f'bump {bump} is a different build ({variant(bump) or "plain"})', 'held'
        return None, f'no in-range version below bump {bump}', 'held'
    dated = [(vk, v, ts) for vk, v, ts in cands if ts]
    if not dated:
        return None, f"mise registry has no dates for {current}..{bump}", 'undated'
    ready = [(vk, v, ts) for vk, v, ts in dated if (NOW - ts).days >= COOLDOWN]
    if ready:
        vk, v, ts = max(ready, key=lambda x: x[0])
        tag = 'bump' if vk == bk else f'< bump {bump}'
        return v, f'{(NOW - ts).days}d old, {tag}', 'ready'
    days_left = max(1, COOLDOWN - max((NOW - ts).days for _, _, ts in dated))
    return None, f'{days_left}d left', 'cooling'


def main():
    outdated = mise_json(['outdated', '--bump', '--json']) or {}
    for tool, info in sorted(outdated.items()):
        current = info.get('current') or ''
        bump = info.get('bump')
        if not bump or not current:
            continue
        if tool in SKIP:
            print(f'  SKIP     {tool:12} {current} -> bump {bump}  (MISE_COOLDOWN_SKIP)', file=sys.stderr)
            continue
        remote = mise_json(['ls-remote', '--json', tool]) or []
        chosen, detail, status = choose(current, bump, remote)
        if status == 'ready':
            print(f'{tool}\t{chosen}')
            print(f'  READY    {tool:12} {current} -> {chosen}  ({detail})', file=sys.stderr)
        elif status == 'cooling':
            print(f'  COOLING  {tool:12} {current} -> bump {bump}  ({detail})', file=sys.stderr)
        elif status == 'undated':
            print(f'  UNDATED  {tool:12} {current} -> bump {bump}  ({detail}; manual)', file=sys.stderr)
        else:  # held
            print(f'  HELD     {tool:12} {current} -> ({detail}; manual)', file=sys.stderr)


if __name__ == '__main__':
    main()

"""Work out hours worked from home for one Australian financial year, from the sleep/wake log plus
timestamps of work activity, applying known leave, holidays, appointments, office and offsite days.

    python3 wfh_backfill.py 2026      # FY 1 Jul 2025 – 30 Jun 2026; run wfh_summary.py first

Reads, next to the log (~/Documents/Financial/Tax/):
  work_from_home_log.csv (+ heartbeat CSV)  via wfh_summary.py's session logic
  work_from_home_FY<yy>-<yy>_daily.csv      from wfh_summary.py, for which days the log is reliable
  wfh_sources/*.jsonl                        work activity: {"ts": ISO 8601} lines (git, GitHub),
                                             slack_daily_*.jsonl {"date","first","last"} for weekdays,
                                             slack_weekend_*.jsonl {"date","times","last"} for weekends
  wfh_sources/day_notes.csv                  date,kind,part,note: leave, TOIL, holidays, office,
                                             offsite and appointments
Writes work_from_home_FY<yy>-<yy>_full.csv and prints a monthly summary.

Any Slack, git or GitHub activity counts as working. A weekday worked at home is:
  - a core day: activity from 06:00 to 19:30, continuing into the evening only while it has no
    gap of an hour or more (shell history helps fill in the day here, since Slack gives only each
    day's first and last message). It starts at
    START, or the first activity if that's earlier. Days covered by the sleep/wake log count only the
    time the laptop was awake, ending when it last slept (often while supervising a long Claude
    task, with no other activity). Other days, and logged days where the log caught less than half
    the activity, end at the last activity plus the typical gap between activity and the laptop's
    sleep, measured on logged days.
  - minus a part-day note ("from 14:30", "09:30-11:00"), 75 minutes per appointment and 30 minutes
    for lunch.
  - plus out-of-hours blocks: activity outside the core day, grouped when less than an hour apart,
    each counted as its span plus half an hour. That's how on-call work at night, at weekends and on
    days off is counted.
Leave, sick, TOIL, holidays and company days off have no core day, but on-call blocks still count
unless the note's part says "no work". A `not-work` note with a time window strikes the activity in it. Office and offsite days count nothing, since they weren't at
home.
"""
import csv
import collections
import glob
import json
import statistics
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import wfh_summary  # noqa: E402

TAX = Path.home() / 'Documents/Financial/Tax'
SOURCES = TAX / 'wfh_sources'
ACTIVITY = ('slack', 'git_commits', 'github', 'claude_prompts')
PRESENCE = ACTIVITY + ('zsh_history',)  # shell use shows the working day's extent, but isn't counted out of hours
START = 9 * 60
CLOCK_OFF_START = 19 * 60 + 30
DAYTIME = (6 * 60, 24 * 60)
BLOCK_GAP, BLOCK_PAD = 60, 30
APPOINTMENT, LUNCH = 75, 30
NOT_WORKING = {'leave', 'sick', 'toil', 'public-holiday', 'company-day-off'}
AWAY = {'office', 'offsite'}


def minutes(t):
    return t.hour * 60 + t.minute + t.second / 60


def hhmm(m):
    return f'{int(m) // 60:02d}:{int(m) % 60:02d}'


def load_activity():
    acts = collections.defaultdict(lambda: collections.defaultdict(list))
    for path in glob.glob(str(SOURCES / '*.jsonl')):
        name = Path(path).stem
        source = 'slack' if name.startswith('slack') else name
        if source not in PRESENCE:
            continue
        for line in open(path):
            row = json.loads(line)
            if 'date' in row:
                times = row.get('times', []) + [row[k] for k in ('first', 'last') if row.get(k)]
                for t in times:
                    acts[date.fromisoformat(row['date'])][source].append(minutes(time.fromisoformat(t)))
            elif 'ts' in row:
                t = datetime.fromisoformat(row['ts'])
                acts[t.date()][source].append(minutes(t.time()))
    return acts


def log_sessions(lo, hi):
    """The sleep/wake log's merged awake sessions, split at midnight, as {date: [(start, end) minutes]}."""
    beat_rows = wfh_summary.read_csv_times(wfh_summary.BEATS)
    beats = sorted(t for t, k in beat_rows if k == 'Awake')
    boots = [(t, k) for t, k in beat_rows if k == 'Boot']
    events = wfh_summary.with_boots_as_wakes(
        sorted(wfh_summary.read_csv_times(wfh_summary.LOG) + boots, key=lambda e: e[0]), beats)
    days = collections.defaultdict(list)
    for a, b in wfh_summary.sessions(events, lo, hi):
        if b - a >= wfh_summary.LEFT_AWAKE:
            continue
        t = a
        while t < b:
            nxt = min(b, datetime.combine(t.date() + timedelta(days=1), time()))
            days[t.date()].append((minutes(t.time()), minutes(nxt.time()) or 24 * 60))
            t = nxt
    return days


def blocks(points):
    """Group activity minutes less than BLOCK_GAP apart; each block counts its span plus BLOCK_PAD."""
    out = []
    for p in sorted(points):
        if out and p - out[-1][1] < BLOCK_GAP:
            out[-1][1] = p
        else:
            out.append([p, p])
    return [(a, b, (b - a + BLOCK_PAD) / 60) for a, b in out]


def core_run(points):
    """The working day's (first, last) activity: everything from 06:00 to CLOCK_OFF_START, then on
    into the evening only while each point is under BLOCK_GAP after the one before. Later points are
    out-of-hours work, e.g. an on-call alert."""
    day = [p for p in sorted(points) if DAYTIME[0] <= p <= DAYTIME[1]]
    if not day:
        return None
    last = day[0]
    for p in day[1:]:
        if p > CLOCK_OFF_START and p - last >= BLOCK_GAP:
            break
        last = p
    return day[0], last


def overlap(a, b, c, d):
    return max(0, min(b, d) - max(a, c))


def part_window(part):
    """A part-day note as the (start, end) minutes taken off, or None."""
    if part.startswith('from '):
        return minutes(time.fromisoformat(part[5:])), 24 * 60
    if '-' in part and ':' in part:
        a, b = part.split('-')
        return minutes(time.fromisoformat(a)), minutes(time.fromisoformat(b))
    return None


def main(fy_end):
    lo, hi = date(fy_end - 1, 7, 1), date(fy_end, 7, 1)
    label = f'FY{(fy_end - 1) % 100:02d}-{fy_end % 100:02d}'
    daily_log = {date.fromisoformat(r['date']): r for r in csv.DictReader(open(TAX / f'work_from_home_{label}_daily.csv'))}
    notes = collections.defaultdict(list)
    for r in csv.DictReader(open(SOURCES / 'day_notes.csv')):
        notes[date.fromisoformat(r['date'])].append(r)
    acts = load_activity()
    sessions = log_sessions(datetime.combine(lo, time()), datetime.combine(hi, time()))

    logged = [d for d, r in daily_log.items() if r['flag'] == '']
    log_from, log_to = min(logged), max(logged)

    def log_ok(d):
        r = daily_log.get(d)
        return log_from <= d <= log_to and r is not None and r['flag'] in ('', 'short-weekday') and sessions.get(d)

    def points(d, sources=PRESENCE):
        return sorted(m for s, ms in acts.get(d, {}).items() if s in sources for m in ms)

    # Calibrate on full logged weekdays: how far the laptop's first wake and last sleep sit outside activity.
    leads, lags = [], []
    for d in (d for d in logged if not notes.get(d) and d.weekday() < 5):
        run = core_run(points(d))
        ss = [s for s in sessions.get(d, []) if run and s[1] > DAYTIME[0] and s[0] <= run[1]]
        if run and ss:
            leads.append(run[0] - ss[0][0])
            lags.append(ss[-1][1] - run[1])
    lead, lag = statistics.median(leads), statistics.median(lags)

    def core_day(d, use_log):
        """(start, end, minutes) of the core working day, or None when there's nothing to anchor it."""
        run = core_run(points(d))
        if not run:
            return None
        if use_log:
            ss = [s for s in sessions.get(d, []) if s[1] > DAYTIME[0] and s[0] <= run[1]]
            if not ss:
                return None
            start = min(max(START, ss[0][0]), run[0])
            end = ss[-1][1]  # the laptop staying awake past the last activity is usually supervising a long Claude task
        else:
            start = min(max(START, run[0] - lead), run[0])
            end = run[1] + lag
        if end <= start:
            return None
        mins = sum(overlap(a, b, start, end) for a, b in sessions[d]) if use_log else end - start
        return start, end, mins

    rows = []
    d = lo
    while d < hi:
        weekday = d.weekday() < 5
        day_notes = notes.get(d, [])
        full_off = [n for n in day_notes if n['part'].startswith('full') and n['kind'].rstrip('?') in NOT_WORKING | AWAY]
        status, source, core = '', '', None
        if full_off:
            status = full_off[0]['kind'].rstrip('?')
        elif weekday:
            use_log = bool(log_ok(d))
            core = core_day(d, use_log)
            fallback = core_day(d, False)
            if fallback and (not core or core[2] < fallback[2] / 2):  # the log missed most of the day
                use_log, core = False, fallback
            status, source = ('wfh', 'log' if use_log else 'activity') if core else ('no-activity', '')

        core_min = cut_min = appt_min = lunch_min = 0.0
        if core:
            start, end, core_min = core
            for n in day_notes:
                w = part_window(n['part'])
                if w and n['kind'] in NOT_WORKING | AWAY:
                    if source == 'log':
                        cut_min += sum(overlap(a, b, max(start, w[0]), min(end, w[1])) for a, b in sessions[d])
                    else:
                        cut_min += overlap(start, end, *w)
            appt_min = APPOINTMENT * sum(1 for n in day_notes if n['kind'] == 'appointment')
            lunch_min = LUNCH

        ooh = []
        if status not in AWAY and not any('no work' in n['part'] for n in day_notes):
            struck = [part_window(n['part']) for n in day_notes if n['kind'] == 'not-work']
            ooh = blocks([p for p in points(d, ACTIVITY) if not (core and core[0] <= p <= core[1])
                          and not any(w and w[0] <= p <= w[1] for w in struck)])
        ooh_hours = sum(h for _, _, h in ooh)
        net = max(core_min - cut_min - appt_min - lunch_min, 0) / 60 + ooh_hours

        if not weekday and not ooh and not day_notes:
            d += timedelta(1)
            continue
        rows.append({
            'date': d.isoformat(), 'weekday': d.strftime('%a'), 'status': status or 'weekend', 'source': source,
            'core_start': hhmm(core[0]) if core else '', 'core_end': hhmm(core[1]) if core else '',
            'core_hours': f'{core_min / 60:.2f}', 'part_day_off': f'{cut_min / 60:.2f}' if cut_min else '',
            'appointments': f'{appt_min / 60:.2f}' if appt_min else '', 'lunch': f'{lunch_min / 60:.2f}' if lunch_min else '',
            'out_of_hours': '; '.join(f'{hhmm(a)}-{hhmm(b)}' for a, b, _ in ooh),
            'out_of_hours_hours': f'{ooh_hours:.2f}' if ooh else '', 'net_hours': f'{net:.2f}',
            'activity_sources': ' '.join(sorted(k for k, v in acts.get(d, {}).items() if v)),
            'notes': ' | '.join(f"{n['kind']} {n['part']}: {n['note']}".strip() for n in day_notes),
        })
        d += timedelta(1)

    out = TAX / f'work_from_home_{label}_full.csv'
    with out.open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        w.writeheader()
        w.writerows(rows)

    # How well an activity-only core day matches the log, on the days the log covers.
    errors = []
    for d in logged:
        if d.weekday() < 5 and not notes.get(d):
            a, b = core_day(d, True), core_day(d, False)
            if a and b:
                errors.append((b[2] - a[2]) / 60)
    q = statistics.quantiles(errors, n=4)
    print(f'logged weekdays: laptop wakes {lead:.0f} min before first activity, sleeps {lag:.0f} min after last (medians); '
          f'activity-only core day minus logged: median {statistics.median(errors):+.2f}h, middle half {q[0]:+.2f}..{q[2]:+.2f}h')

    def total(rs, key):
        return sum(float(r[key] or 0) for r in rs)

    cols = ('wfh_days', 'core_h', 'off_h', 'appt_h', 'lunch_h', 'ooh_h', 'net_h')
    print(f"{'month':8} " + ' '.join(f'{c:>8}' for c in cols))
    totals = collections.Counter()
    for month in sorted({r['date'][:7] for r in rows}):
        m = [r for r in rows if r['date'][:7] == month]
        row = collections.Counter(
            wfh_days=sum(1 for r in m if r['status'] == 'wfh'), core_h=total(m, 'core_hours'),
            off_h=total(m, 'part_day_off'), appt_h=total(m, 'appointments'), lunch_h=total(m, 'lunch'),
            ooh_h=total(m, 'out_of_hours_hours'), net_h=total(m, 'net_hours'))
        totals.update(row)
        print(f'{month:8} ' + ' '.join(f'{row[c]:8d}' if c == 'wfh_days' else f'{row[c]:8.1f}' for c in cols))
    print(f"{'total':8} " + ' '.join(f'{totals[c]:8d}' if c == 'wfh_days' else f'{totals[c]:8.1f}' for c in cols))
    by_status = collections.Counter(r['status'] for r in rows)
    print('days by status:', dict(by_status))
    print('out-of-hours hours by day type:', {s: round(total([r for r in rows if r['status'] == s], 'out_of_hours_hours'), 1)
                                              for s in by_status})
    print(f'wrote {out}')


if __name__ == '__main__':
    main(int(sys.argv[1]) if len(sys.argv) > 1 else date.today().year)

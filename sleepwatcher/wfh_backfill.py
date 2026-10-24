"""Fill the gaps in the sleep/wake work-from-home record from timestamps of work activity, and
apply known leave, holidays, office and offsite days, for one Australian financial year.

    python3 wfh_backfill.py 2026      # FY 1 Jul 2025 – 30 Jun 2026; run wfh_summary.py first

Reads, next to the log (~/Documents/Financial/Tax/):
  work_from_home_FY<yy>-<yy>_daily.csv     from wfh_summary.py
  wfh_sources/*.jsonl                      activity timestamps, one {"ts": ISO 8601} per line, plus
                                           slack_daily_*.jsonl rows of {"date", "first", "last"}
  wfh_sources/day_notes.csv                date,kind,part,note for leave, TOIL, holidays, office, offsite
Writes work_from_home_FY<yy>-<yy>_full.csv and prints a monthly summary.

How a weekday's hours are decided:
  - A note for the whole day (leave, sick, TOIL, a public holiday, a company day off) makes it 0.
    So does a whole day in the office or at an offsite, since those hours weren't at home.
  - Otherwise the sleep/wake log is used where it was recording normally, unless it shows no hours
    on a day with work activity (it missed a wake).
  - Otherwise the hours are estimated from the first and last activity that day, widened by the
    typical gap between activity and the laptop's own wake/sleep on days the log covers. A part-day
    note ("from 14:30") cuts the estimate off at that time.
"""
import csv
import collections
import glob
import json
import statistics
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path

TAX = Path.home() / 'Documents/Financial/Tax'
SOURCES = TAX / 'wfh_sources'
DAY_START, DAY_END = time(6), time(23, 59)
NOT_WORKING = {'leave', 'sick', 'toil', 'public-holiday', 'company-day-off'}
AWAY = {'office', 'offsite'}
# Sources that cover the whole year. Denser ones that only exist for part of it (e.g. Claude Code
# prompts) would make estimated days look longer than calibrated ones, so they're left out.
SOURCES_USED = ('slack', 'zsh_history', 'git_commits', 'github')


def minutes(t):
    return t.hour * 60 + t.minute + t.second / 60


def hhmm(m):
    return f'{int(m) // 60:02d}:{int(m) % 60:02d}'


def load_activity():
    acts = collections.defaultdict(lambda: collections.defaultdict(list))
    for path in glob.glob(str(SOURCES / '*.jsonl')):
        name = Path(path).stem
        for line in open(path):
            row = json.loads(line)
            if name.startswith('slack_daily'):
                for key in ('first', 'last'):
                    if row.get(key):
                        acts[date.fromisoformat(row['date'])]['slack'].append(minutes(time.fromisoformat(row[key])))
            elif 'ts' in row and name in SOURCES_USED:
                t = datetime.fromisoformat(row['ts'])
                acts[t.date()][name].append(minutes(t.time()))
    lo, hi = minutes(DAY_START), minutes(DAY_END)
    return {d: {s: [m for m in ms if lo <= m <= hi] for s, ms in by.items()} for d, by in acts.items()}


def span(day_acts):
    points = [m for ms in day_acts.values() for m in ms]
    return (min(points), max(points), len(points)) if points else None


def part_cutoff(part):
    if part.startswith('from '):
        return minutes(time.fromisoformat(part[5:]))
    return None


def main(fy_end):
    lo, hi = date(fy_end - 1, 7, 1), date(fy_end, 7, 1)
    label = f'FY{(fy_end - 1) % 100:02d}-{fy_end % 100:02d}'
    log = {date.fromisoformat(r['date']): r for r in csv.DictReader(open(TAX / f'work_from_home_{label}_daily.csv'))}
    notes = {date.fromisoformat(r['date']): r for r in csv.DictReader(open(SOURCES / 'day_notes.csv'))}
    acts = load_activity()

    # The log only counts while it was actually running: from its first full day to its last.
    logged = [d for d, r in log.items() if r['flag'] == '']
    log_from, log_to = min(logged), max(logged)

    def log_ok(d):
        r = log.get(d)
        return log_from <= d <= log_to and (r is None or r['flag'] in ('', 'short-weekday', 'weekend'))

    # Calibrate on full logged weekdays: how far the laptop's wake/sleep sits outside first/last activity.
    leads, lags, errors, covered = [], [], [], 0
    full_days = [d for d, r in log.items() if r['flag'] == '' and d not in notes]
    for d in full_days:
        s = span(acts.get(d, {}))
        if not s:
            continue
        covered += 1
        r = log[d]
        leads.append(s[0] - minutes(time.fromisoformat(r['first_active'])))
        last = r['last_active']
        lags.append((24 * 60 if last == '00:00' else minutes(time.fromisoformat(last))) - s[1])
    lead, lag = statistics.median(leads), statistics.median(lags)
    for d in full_days:
        s = span(acts.get(d, {}))
        if s:
            est = (min(s[1] + lag, 24 * 60) - max(s[0] - lead, minutes(DAY_START))) / 60
            errors.append(est - float(log[d]['recorded_hours']))

    rows = []
    d = lo
    while d < hi:
        weekday = d.weekday() < 5
        note = notes.get(d)
        r = log.get(d)
        s = span(acts.get(d, {}))
        status, hours, source = '', 0.0, ''
        if note and note['part'] == 'full' and note['kind'].rstrip('?') in NOT_WORKING | AWAY:
            status = note['kind']
        elif log_ok(d) and (weekday or r) and (r and float(r['recorded_hours']) or not s):
            # A logged day with no hours but real activity means the log missed the wake, so estimate it
            hours = float(r['recorded_hours']) if r else 0.0
            status, source = ('wfh' if hours else 'no-activity'), 'log'
        elif weekday and s:
            start = max(s[0] - lead, minutes(DAY_START))
            end = min(s[1] + lag, 24 * 60)
            cut = part_cutoff(note['part']) if note else None
            if cut is not None:
                end = min(end, cut)
            hours = max(end - start, 0) / 60
            status, source = 'wfh', 'estimated'
        elif weekday:
            status = 'no-activity'
        if not weekday and not hours and not note:
            d += timedelta(1)
            continue
        rows.append({
            'date': d.isoformat(), 'weekday': d.strftime('%a'), 'status': status, 'wfh_hours': f'{hours:.2f}',
            'source': source, 'log_hours': r['recorded_hours'] if r else '', 'log_flag': r['flag'] if r else '',
            'activity_first': hhmm(s[0]) if s else '', 'activity_last': hhmm(s[1]) if s else '',
            'activity_points': s[2] if s else 0,
            'activity_sources': ' '.join(sorted(k for k, v in acts.get(d, {}).items() if v)),
            'note_kind': note['kind'] if note else '', 'note_part': note['part'] if note else '',
            'note': note['note'] if note else '',
        })
        d += timedelta(1)

    out = TAX / f'work_from_home_{label}_full.csv'
    with out.open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator='\n')
        w.writeheader()
        w.writerows(rows)

    print(f'calibration on {len(full_days)} full logged weekdays: {covered} had activity; '
          f'laptop wakes {lead:.0f} min before first activity and sleeps {lag:.0f} min after last (medians); '
          f'estimate minus log hours: median {statistics.median(errors):+.2f}h, '
          f'middle half {statistics.quantiles(errors, n=4)[0]:+.2f}..{statistics.quantiles(errors, n=4)[2]:+.2f}h')
    print(f"{'month':8} {'wfh_days':>8} {'log_h':>7} {'est_h':>7} {'total_h':>8} {'weekend_h':>9} {'off_days':>8} {'away_days':>9} {'no_act':>6}")
    totals = collections.Counter()
    for month in sorted({r['date'][:7] for r in rows}):
        m = [r for r in rows if r['date'][:7] == month]
        row = collections.Counter(
            wfh_days=sum(1 for r in m if r['status'] == 'wfh' and r['weekday'] not in ('Sat', 'Sun')),
            log_h=sum(float(r['wfh_hours']) for r in m if r['source'] == 'log' and r['weekday'] not in ('Sat', 'Sun')),
            est_h=sum(float(r['wfh_hours']) for r in m if r['source'] == 'estimated'),
            weekend_h=sum(float(r['wfh_hours']) for r in m if r['weekday'] in ('Sat', 'Sun')),
            off_days=sum(1 for r in m if r['status'].rstrip('?') in NOT_WORKING),
            away_days=sum(1 for r in m if r['status'] in AWAY),
            no_act=sum(1 for r in m if r['status'] == 'no-activity'))
        row['total_h'] = row['log_h'] + row['est_h']
        totals.update(row)
        print(f"{month:8} {row['wfh_days']:8d} {row['log_h']:7.1f} {row['est_h']:7.1f} {row['total_h']:8.1f} "
              f"{row['weekend_h']:9.1f} {row['off_days']:8d} {row['away_days']:9d} {row['no_act']:6d}")
    print(f"{'total':8} {totals['wfh_days']:8d} {totals['log_h']:7.1f} {totals['est_h']:7.1f} {totals['total_h']:8.1f} "
          f"{totals['weekend_h']:9.1f} {totals['off_days']:8d} {totals['away_days']:9d} {totals['no_act']:6d}")
    print('log hours not counted (day noted off/away):', ', '.join(
        f"{r['date']} {r['status']} {float(r['log_hours']):.1f}h" for r in rows
        if r['log_hours'] and float(r['log_hours']) and not float(r['wfh_hours'])))
    print('no-activity weekdays:', ', '.join(r['date'] for r in rows if r['status'] == 'no-activity'))
    print('activity on a day noted off/away:', ', '.join(
        f"{r['date']} {r['status']} ({r['activity_first']}-{r['activity_last']}, {r['activity_points']} pts)"
        for r in rows if r['status'].rstrip('?') in NOT_WORKING | AWAY and r['activity_points']))
    print(f'wrote {out}')


if __name__ == '__main__':
    main(int(sys.argv[1]) if len(sys.argv) > 1 else date.today().year)

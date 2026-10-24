"""Turn the sleep/wake log (written by the sleepwatcher hooks) into work-from-home hours for one
Australian financial year.

    python3 wfh_summary.py 2026      # FY 1 Jul 2025 – 30 Jun 2026

Writes, next to the log:
  work_from_home_FY<yy>-<yy>_events.csv   the raw Sleep/Wake lines inside the FY
  work_from_home_FY<yy>-<yy>_daily.csv    one row per day with hours, first/last activity and a flag
and prints a monthly summary.

Cleaning rules:
  - A session is a Wake followed by a Sleep. Sessions under 5 minutes are dropped: they're the
    Mac's scheduled maintenance wakes (most last 0–1 seconds).
  - Sessions less than 10 minutes apart are merged (lid closed briefly, a short walk away).
  - Time between midnight and 06:00 isn't counted.
  - A session of 16 to 72 hours means the Mac was left awake overnight, so the hours worked are
    unknown. Its weekdays are flagged `left-awake` and estimated at the median full weekday.
  - A session of 72 hours or more is a gap in the log (the Mac was off, or away for days), so its
    days are flagged `no-data` and not counted.
"""
import csv
import collections
import statistics
import sys
from datetime import date, datetime, time, timedelta
from pathlib import Path

LOG = Path.home() / 'Documents/Financial/Tax/work_from_home_log.csv'
MIN_SESSION = timedelta(minutes=5)
MERGE_GAP = timedelta(minutes=10)
LEFT_AWAKE = timedelta(hours=16)
LOG_GAP = timedelta(hours=72)
DAY_START = time(6)
CORE_START, CORE_END = time(8), time(18)  # a long session flags a day only if it spans an hour of these
SHORT_WEEKDAY_HOURS = 4


def sessions(events, lo, hi):
    raw = [[t1, t2] for (t1, k1), (t2, k2) in zip(events, events[1:])
           if k1 == 'Wake' and k2 == 'Sleep' and t2 - t1 >= MIN_SESSION and t1 < hi and t2 > lo]
    merged = []
    for s in raw:
        if merged and s[0] - merged[-1][1] < MERGE_GAP:
            merged[-1][1] = max(merged[-1][1], s[1])
        else:
            merged.append(s)
    return merged


def daily(merged, lo, hi):
    days = collections.defaultdict(lambda: {'hours': 0.0, 'first': None, 'last': None, 'sessions': 0, 'left_awake': False, 'no_data': False})
    for a, b in merged:
        gap = b - a >= LOG_GAP
        long = b - a >= LEFT_AWAKE
        t = max(a, lo)
        while t < min(b, hi):
            d = t.date()
            nxt = min(b, hi, datetime.combine(d + timedelta(days=1), time()))
            day = days[d]
            core = min(nxt, datetime.combine(d, CORE_END)) - max(t, datetime.combine(d, CORE_START))
            if gap and core >= timedelta(hours=1):
                day['no_data'] = True
            elif long and core >= timedelta(hours=1):
                day['left_awake'] = True
            else:
                start = max(t, datetime.combine(d, DAY_START))
                if nxt > start:
                    day['hours'] += (nxt - start).total_seconds() / 3600
                    day['first'] = min(filter(None, [day['first'], start]))
                    day['last'] = max(filter(None, [day['last'], nxt]))
                    day['sessions'] += 1
            t = nxt
    return days


def flag(d, day):
    if day['left_awake']:
        return 'left-awake'
    if day['no_data'] and not day['sessions']:
        return 'no-data'
    if d.weekday() >= 5:
        return 'weekend'
    if day['hours'] < SHORT_WEEKDAY_HOURS:
        return 'short-weekday'
    return ''


def main(fy_end):
    lo, hi = datetime(fy_end - 1, 7, 1), datetime(fy_end, 7, 1)
    label = f'FY{(fy_end - 1) % 100:02d}-{fy_end % 100:02d}'
    with LOG.open() as f:
        events = [(datetime.strptime(f'{d} {t}', '%Y-%m-%d %H:%M:%S'), k) for d, t, k in csv.reader(f)]

    in_fy = [(t, k) for t, k in events if lo <= t < hi]
    with (LOG.parent / f'work_from_home_{label}_events.csv').open('w', newline='') as f:
        csv.writer(f, lineterminator='\n').writerows((t.strftime('%Y-%m-%d'), t.strftime('%H:%M:%S'), k) for t, k in in_fy)

    days = daily(sessions(events, lo, hi), lo, hi)
    median_day = statistics.median(v['hours'] for d, v in days.items() if flag(d, v) == '')

    def estimate(d, v):
        return median_day if flag(d, v) == 'left-awake' and d.weekday() < 5 else 0.0

    with (LOG.parent / f'work_from_home_{label}_daily.csv').open('w', newline='') as f:
        w = csv.writer(f, lineterminator='\n')
        w.writerow(['date', 'weekday', 'recorded_hours', 'estimated_hours', 'first_active', 'last_active', 'sessions', 'flag'])
        for d in sorted(days):
            v = days[d]
            w.writerow([d, d.strftime('%a'), f"{v['hours']:.2f}", f'{estimate(d, v):.2f}' if estimate(d, v) else '',
                        v['first'] and v['first'].strftime('%H:%M'), v['last'] and v['last'].strftime('%H:%M'),
                        v['sessions'], flag(d, v)])

    first_day, last_day = in_fy[0][0].date(), in_fy[-1][0].date()
    print(f'{label}: {len(in_fy)} raw events, {in_fy[0][0]:%Y-%m-%d %H:%M} to {in_fy[-1][0]:%Y-%m-%d %H:%M}')
    print(f'median full weekday: {median_day:.2f}h')
    cols = ['full_days', 'recorded_h', 'est_days', 'est_h', 'short_days', 'short_h', 'weekend_h', 'nodata_wd', 'silent_wd']
    print(f"{'month':8} " + ' '.join(f'{c:>10}' for c in cols))
    totals = collections.Counter()
    for month in sorted({(lo.date() + timedelta(n)).strftime('%Y-%m') for n in range((hi - lo).days)}):
        span = [lo.date() + timedelta(n) for n in range((hi - lo).days)]
        span = [d for d in span if d.strftime('%Y-%m') == month and d.weekday() < 5]
        m = {d: v for d, v in days.items() if d.strftime('%Y-%m') == month}
        row = collections.Counter(
            full_days=sum(1 for d, v in m.items() if flag(d, v) == ''),
            recorded_h=sum(v['hours'] for d, v in m.items() if d.weekday() < 5),
            est_days=sum(1 for d, v in m.items() if estimate(d, v)),
            est_h=sum(estimate(d, v) for d, v in m.items()),
            short_days=sum(1 for d, v in m.items() if flag(d, v) == 'short-weekday'),
            short_h=sum(v['hours'] for d, v in m.items() if flag(d, v) == 'short-weekday'),
            weekend_h=sum(v['hours'] for d, v in m.items() if d.weekday() >= 5),
            nodata_wd=sum(1 for d in span if d in days and flag(d, days[d]) == 'no-data'),
            silent_wd=sum(1 for d in span if d not in days and first_day <= d <= last_day))
        totals.update(row)
        print(f'{month:8} ' + ' '.join(f'{row[c]:10.1f}' if c.endswith('_h') else f'{row[c]:10d}' for c in cols))
    print(f"{'total':8} " + ' '.join(f'{totals[c]:10.1f}' if c.endswith('_h') else f'{totals[c]:10d}' for c in cols))
    before = sum(1 for n in range((first_day - lo.date()).days) if (lo.date() + timedelta(n)).weekday() < 5)
    print(f'weekdays before the log started ({first_day}): {before}')
    for name in ('left-awake', 'no-data', 'short-weekday'):
        print(f'{name}:', ', '.join(f"{d:%a %d %b}" + (f" ({v['hours']:.1f}h)" if name == 'short-weekday' else '')
                                    for d, v in sorted(days.items()) if flag(d, v) == name and d.weekday() < 5))
    print('silent weekdays inside the log:', ', '.join(f'{d:%a %d %b}' for d in
          (first_day + timedelta(n) for n in range((last_day - first_day).days)) if d.weekday() < 5 and d not in days))

if __name__ == '__main__':
    main(int(sys.argv[1]) if len(sys.argv) > 1 else date.today().year)

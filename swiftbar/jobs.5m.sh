#!/bin/bash
# <swiftbar.title>Jobs</swiftbar.title>
# <swiftbar.desc>Failures and overdue runs for scheduled jobs that report via ~/bin/job-status</swiftbar.desc>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
#
# Linked into SwiftBar's plugin folder by install.sh. job-status refreshes this
# plugin when a job changes state; the 5m interval catches jobs going stale.

STATE_ROOT="$HOME/Library/Application Support/job-status"
JOB_STATUS="$HOME/bin/job-status"
NOW=$(date +%s)

get() { cat "$STATE_ROOT/$1/$2" 2>/dev/null; }
put() { printf '%s\n' "$3" > "$STATE_ROOT/$1/.$2.tmp" && mv -f "$STATE_ROOT/$1/.$2.tmp" "$STATE_ROOT/$1/$2"; }

# seconds → 45s / 12m / 5h / 2d 3h
dur() {
    local s=$1
    if   (( s < 60 ));    then echo "${s}s"
    elif (( s < 3600 ));  then echo "$(( s / 60 ))m"
    elif (( s < 86400 )); then echo "$(( s / 3600 ))h"
    elif (( s % 86400 < 3600 )); then echo "$(( s / 86400 ))d"
    else echo "$(( s / 86400 ))d $(( s % 86400 / 3600 ))h"
    fi
}
when() { echo "$(date -r "$1" '+%a %-d %b %H:%M') ($(dur $(( NOW - $1 ))) ago)"; }
# Menu text can't contain SwiftBar's | separator
clean() { printf '%s' "${1//|/¦}"; }

notify() {
    osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "Basso"' -e 'end run' \
        "$1" "$2" &>/dev/null
}

problems=0; bad_rows=""; ok_rows=""

for path in "$STATE_ROOT"/*/; do
    [ -d "$path" ] || continue
    job=$(basename "$path")
    status=$(get "$job" status); since=$(get "$job" since); message=$(get "$job" message)
    last_ok=$(get "$job" last_ok); created=$(get "$job" created); max_age=$(get "$job" max_age)
    last_skip=$(get "$job" last_skip); skip_message=$(get "$job" skip_message)
    log=$(get "$job" log); dismissed=$(get "$job" dismissed); dismissed=${dismissed:-0}
    name=$(get "$job" title); name=$(clean "${name:-$job}")
    ref=${last_ok:-$created}

    state=ok
    if [ "$status" = fail ] && (( dismissed <= since )); then
        state=fail
    elif [ -n "$max_age" ] && (( NOW - ref > max_age )) && (( dismissed <= ref )); then
        state=stale
        if [ "$(get "$job" stale_notified)" != "$ref" ]; then
            notify "$name" "No successful run for $(dur $(( NOW - ref )))"
            put "$job" stale_notified "$ref"
        fi
    fi

    case $state in
        fail)  row="$name — failed $(dur $(( NOW - since ))) ago | sfimage=xmark.octagon.fill sfcolor=#d1242f symbolize=false" ;;
        stale) row="$name — no success for $(dur $(( NOW - ref ))) | sfimage=clock.badge.exclamationmark sfcolor=#d4a72c symbolize=false" ;;
        *)     if [ -n "$last_ok" ]; then row="$name — ok $(dur $(( NOW - last_ok ))) ago | sfimage=checkmark.circle symbolize=false"
               else row="$name — no success yet | sfimage=circle.dashed symbolize=false"; fi ;;
    esac
    [ -n "$message" ] && row+=$'\n'"--$(clean "$message") | symbolize=false"
    if [ -n "$last_ok" ]; then row+=$'\n'"--Last success: $(when "$last_ok") | symbolize=false"
    else row+=$'\n'"--Last success: never | symbolize=false"; fi
    if [ -n "$last_skip" ] && (( last_skip > ${last_ok:-0} )); then
        row+=$'\n'"--Last skipped: $(when "$last_skip")${skip_message:+ — $(clean "$skip_message")} | symbolize=false"
    fi
    [ -n "$max_age" ] && row+=$'\n'"--Stale after $(dur "$max_age") without success | symbolize=false"
    [ -n "$log" ] && row+=$'\n'"--Open log | bash=/usr/bin/open param1=\"$log\" terminal=false"
    [ "$state" != ok ] && row+=$'\n'"--Dismiss until it changes | bash=$JOB_STATUS param1=$job param2=dismiss terminal=false refresh=true"
    row+=$'\n'"--Forget this job | bash=$JOB_STATUS param1=$job param2=forget terminal=false refresh=true"

    if [ "$state" = ok ]; then ok_rows+="$row"$'\n'
    else problems=$(( problems + 1 )); bad_rows+="$row"$'\n'; fi
done

if (( problems > 0 )); then
    echo "$problems | sfimage=exclamationmark.triangle.fill sfcolor=#d1242f"
else
    echo "| sfimage=checkmark.circle"
fi
echo "---"
[ -z "$bad_rows$ok_rows" ] && echo "No jobs have reported yet | symbolize=false"
printf '%s' "$bad_rows"
[ -n "$bad_rows" ] && [ -n "$ok_rows" ] && echo "---"
printf '%s' "$ok_rows"
echo "---"
echo "Refresh | refresh=true"

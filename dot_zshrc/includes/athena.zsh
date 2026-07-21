# athena-q — run a query against the Fat Zebra prod datalake and print the result.
#
# Wraps the async `aws athena` dance (start → poll → fetch) into one call, prints
# an aligned table, and reports bytes scanned + $ cost (Athena bills ~$5 per TB
# scanned, rounded up per query — tens of GB is cents; it only matters at TB scale).
#
# Auth: IAM Identity Center via the `datalake` profile (see ~/.config/aws/config).
# If the SSO token has expired it tells you to run `aws sso login --profile datalake`.
#
# Usage:
#   athena-q 'SELECT * FROM coredb.some_table LIMIT 20'
#   athena-q --csv 'SELECT ...' > out.csv
#   echo 'SELECT ...' | athena-q
#   athena-q --wg primary --profile datalake 'SELECT ...'   # overrides
athena-q() {
  local profile=datalake workgroup=prod-datalake fmt=table
  while [[ "$1" == -* ]]; do
    case "$1" in
      --csv)     fmt=csv; shift ;;
      --wg)      workgroup="$2"; shift 2 ;;
      --profile) profile="$2"; shift 2 ;;
      -h|--help) echo "usage: athena-q [--csv] [--wg WORKGROUP] [--profile PROFILE] 'SQL'"; return 0 ;;
      *)         echo "athena-q: unknown flag $1" >&2; return 2 ;;
    esac
  done

  local sql="$*"
  [[ -z "$sql" && ! -t 0 ]] && sql="$(cat)"   # fall back to stdin
  if [[ -z "$sql" ]]; then echo "athena-q: no SQL given" >&2; return 2; fi

  local err; err=$(mktemp)
  local qid
  qid=$(aws athena start-query-execution --profile "$profile" \
          --work-group "$workgroup" --query-string "$sql" \
          --query QueryExecutionId --output text 2>"$err")

  # Expired SSO token: if we're at an interactive terminal, open the browser to
  # log in and retry once. In a pipe/script (no tty) just print the hint — never
  # block on a browser that can't be driven.
  if [[ -z "$qid" ]] && grep -qiE 'sso|token has expired|forbidden|expiredtoken' "$err"; then
    if [[ -t 2 ]]; then
      echo "athena-q: SSO session expired — opening browser to log in..." >&2
      if aws sso login --profile "$profile" >&2; then
        qid=$(aws athena start-query-execution --profile "$profile" \
                --work-group "$workgroup" --query-string "$sql" \
                --query QueryExecutionId --output text 2>"$err")
      fi
    else
      echo "athena-q: SSO session expired — run: aws sso login --profile $profile" >&2
    fi
  fi

  if [[ -z "$qid" ]]; then
    sed 's/^/athena-q: /' "$err" >&2
    rm -f "$err"; return 1
  fi
  rm -f "$err"

  # Poll until the query leaves the running states.
  local state
  while :; do
    state=$(aws athena get-query-execution --profile "$profile" \
              --query-execution-id "$qid" \
              --query 'QueryExecution.Status.State' --output text 2>/dev/null)
    [[ "$state" == SUCCEEDED ]] && break
    if [[ "$state" == FAILED || "$state" == CANCELLED ]]; then
      local reason
      reason=$(aws athena get-query-execution --profile "$profile" \
                 --query-execution-id "$qid" \
                 --query 'QueryExecution.Status.StateChangeReason' --output text 2>/dev/null)
      echo "athena-q: query $state — $reason" >&2
      return 1
    fi
    sleep 1
  done

  # Report scan volume + cost (to stderr, so stdout stays pipe-clean).
  local bytes
  bytes=$(aws athena get-query-execution --profile "$profile" \
            --query-execution-id "$qid" \
            --query 'QueryExecution.Statistics.DataScannedInBytes' --output text 2>/dev/null)
  awk -v b="${bytes:-0}" 'BEGIN{
    gb=b/1073741824; printf "athena-q: scanned %.2f GB (~$%.4f at $5/TB)\n", gb, b/1099511627776*5 > "/dev/stderr"
    if (b > 536870912000) print "athena-q: \342\232\240 large scan (>500 GB)" > "/dev/stderr"
  }'

  # Fetch results (CLI auto-paginates) and format via python for correct
  # handling of NULL cells and embedded commas.
  aws athena get-query-results --profile "$profile" --query-execution-id "$qid" --output json 2>/dev/null \
    | python3 -c '
import json, sys, csv
fmt = sys.argv[1]
d = json.load(sys.stdin)
rows = [[c.get("VarCharValue", "") for c in r.get("Data", [])] for r in d["ResultSet"]["Rows"]]
if not rows:
    sys.exit(0)
if fmt == "csv":
    csv.writer(sys.stdout).writerows(rows)
else:
    w = [max(len(r[i]) if i < len(r) else 0 for r in rows) for i in range(len(rows[0]))]
    for n, r in enumerate(rows):
        print("  ".join((r[i] if i < len(r) else "").ljust(w[i]) for i in range(len(w))))
        if n == 0:
            print("  ".join("-" * x for x in w))
' "$fmt"
}

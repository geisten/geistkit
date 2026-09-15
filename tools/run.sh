#!/bin/sh
# run.sh KEY DIR CMD... — run CMD in DIR, write the log to build/logs/KEY.log,
# and record the exit code and test counts in build/results/KEY.tsv.
# Always exits 0: tools/verify.sh decides, so one failure does not hide the rest.
set -u
key=$1 dir=$2
shift 2
mkdir -p build/logs build/results
log=build/logs/$key.log
printf '== %s\n' "$key"
( cd "$dir" && "$@" ) >"$log" 2>&1
rc=$?
[ "$rc" -eq 0 ] || printf '   exit %s -> %s\n' "$rc" "$log"
{
    printf '%s.exit\t%s\n' "$key" "$rc"
    # geistlib mk/run-tests.sh: "Ran N test(s) in Xs: P passed, S skipped, F failed, E error"
    # geistshell make test:     "test summary: passed=P skipped=S host_skipped=H"
    awk -v k="$key" '
        /^Ran [0-9]+ test\(s\) in / {
            sub(/^[^:]*: /, "")
            n = split($0, part, /, /)
            for (i = 1; i <= n; i++) { split(part[i], w, " "); printf "%s.%s\t%s\n", k, w[2], w[1] }
        }
        /^test summary:/ {
            for (i = 3; i <= NF; i++) { split($i, kv, "="); printf "%s.%s\t%s\n", k, kv[1], kv[2] }
        }' "$log"
} >"build/results/$key.tsv"

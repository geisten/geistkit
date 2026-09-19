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
        }
        # geistlib tests/bench_perf_sweep: one JSON object per seq_len, core metrics are the
        # mean over --repeats. Only the four flat keys below are taken, so the nested
        # "samples" arrays cannot leak in: their keys simply never match.
        # geist-diktat tests/e2e_wer.sh prints the scorer line; the test gates itself at 15 %,
        # this keeps the number as data so a drift is visible before it crosses the threshold.
        /aggregate WER:/ {
            if (match($0, /aggregate WER: [0-9.]+/))
                printf "%s.wer_pct\t%s\n", k, substr($0, RSTART + 15, RLENGTH - 15)
        }
        /"prefill_tps":/ {
            n = split($0, part, /[,{}]/)
            for (i = 1; i <= n; i++) {
                if (split(part[i], kv, ":") != 2) continue
                gsub(/[" ]/, "", kv[1])
                if (kv[1] ~ /^(prefill_tps|decode_tps|rss_mb|threads)$/)
                    printf "%s.%s\t%s\n", k, kv[1], kv[2]
            }
        }' "$log"
} >"build/results/$key.tsv"

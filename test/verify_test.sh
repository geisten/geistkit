#!/bin/sh
# Self-test for tools/verify.sh: requirement met, violated, value missing,
# exit != 0 without a requirement, unknown operator, and decimal values —
# throughput floors are decimals, so that comparison has to hold.
set -u
d=$(mktemp -d)
trap 'rm -rf "$d"' EXIT
printf 'a.exit\t0\na.skipped\t3\nb.exit\t2\nc.prefill_tps\t680.339\n' >"$d/results"

expect() { # expected exit code, acceptance lines
    printf '%s\n' "$2" >"$d/acc"
    sh tools/verify.sh "$d/results" "$d/acc" >/dev/null
    rc=$?
    [ "$rc" -eq "$1" ] || { printf 'FAIL: expected %s, got %s for:\n%s\n' "$1" "$rc" "$2"; exit 1; }
}

expect 0 'a.skipped <= 3
b.exit == 2'
expect 1 'a.skipped <= 2
b.exit == 2'
expect 1 'a.missing == 0
b.exit == 2'
expect 1 'a.skipped <= 3'
expect 1 'a.skipped ~= 3
b.exit == 2'
# Decimals: a floor below the measured value holds, one above it fails.
expect 0 'c.prefill_tps >= 150
b.exit == 2'
expect 1 'c.prefill_tps >= 700.5
b.exit == 2'
echo "verify selftest: ok"

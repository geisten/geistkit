#!/bin/sh
# verify.sh RESULTS ACCEPTANCE — compare measured values against requirements.
# Fails if a requirement is violated, a measured value is missing, the operator
# is unknown, or any step exited non-zero without a requirement allowing it.
set -u
awk '
    FNR == NR { got[$1] = $2; next }
    /^[[:space:]]*(#|$)/ { next }
    {
        k = $1; op = $2; want = $3; seen[k] = 1
        if (!(k in got)) { printf "FAIL  %-36s missing (step did not run?)\n", k; bad = 1; next }
        g = got[k] + 0; w = want + 0
        ok = (op == "==" && g == w) || (op == "<=" && g <= w) || (op == ">=" && g >= w)
        printf "%s  %-36s %s %s %s\n", ok ? "ok  " : "FAIL", k, got[k], op, want
        if (!ok) bad = 1
    }
    END {
        for (k in got)
            if (k ~ /\.exit$/ && got[k] != 0 && !(k in seen)) {
                printf "FAIL  %-36s exit %s (no requirement)\n", k, got[k]; bad = 1
            }
        exit bad
    }' "$1" "$2"

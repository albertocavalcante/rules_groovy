#!/usr/bin/env bash
# Wrapper invoked by the `codenarc` sh_test. Bazel passes rlocation
# paths to the cli binary and the ruleset file as $1 and $2.
#
# CodeNarc walks `-basedir` for `**/*.groovy` matching the `-includes`
# glob. Under `bazel test`, the runfiles tree contains
# `src/main/groovy/...` sources at their workspace-rooted paths; we
# anchor `-basedir` at `$PWD` (the sh_test's working dir) so CodeNarc
# walks the same tree.
set -euo pipefail

cli="$1"
ruleset="$2"

# Runs from the sh_test's runfiles dir. The `src/main/groovy/**/*.groovy`
# tree is rooted there, so `-basedir=.` is sufficient.
exec "${cli}" \
    -basedir=. \
    -includes='src/**/*.groovy' \
    -rulesetfiles="file:${ruleset}" \
    -title='rules_groovy CodeNarc example' \
    -maxPriority1Violations=0 \
    -maxPriority2Violations=0 \
    -maxPriority3Violations=0 \
    -report=console

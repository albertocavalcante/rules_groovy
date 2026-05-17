#!/usr/bin/env bash
# Copyright 2025-present Alberto Cavalcante. All rights reserved.
# Licensed under the Apache License, Version 2.0.
#
# Bazel-executable wrapper around the bundled Apache Groovy launcher.
#
# Responsibilities:
#   1. Locate the bundled `bin/groovyc` inside the action's sandbox layout.
#   2. Expand `@argfile` arguments before delegating, because Groovy 2.5.x's
#      FileSystemCompiler does not understand argument files. Groovy 3.0+ does;
#      chapter 6 of the v0.1.0 narrative makes 4.0.x the default and reduces
#      the argfile-expansion case to a pass-through.
#   3. When `-d <path>` is a `.jar`, redirect groovyc to a temp directory
#      (groovyc 2.5.x only writes class trees to a directory) and then pack
#      with `$JAVA_HOME/bin/jar` into the requested jar. A separate singlejar
#      action then normalizes the jar and adds directory entries (ISSUE-051).
#
# Invoked under `ctx.actions.run` (not `run_shell`) with an explicit JAVA_HOME
# in `env =`; no `use_default_shell_env`, no host PATH leak. See ISSUE-040.

set -eu

# --- Locate the bundled groovyc launcher ----------------------------------
# This script is `@groovy_sdk_artifact//:groovyc` (a sh_binary). For
# `ctx.actions.run`, Bazel stages the sh_binary's `data` (the SDK files) at
# their exec-relative paths under the action's execroot:
#
#   external/<sdk_repo>/groovy-X.Y.Z/bin/groovyc                       ← target
#
# We scan rather than hard-code `groovy-2.5.8` because chapter 5 will
# register multiple SDK versions simultaneously.
GROOVYC=""
for candidate in external/*/groovy-*/bin/groovyc; do
    if [ -f "$candidate" ]; then
        GROOVYC="$candidate"
        break
    fi
done

if [ -z "$GROOVYC" ]; then
    echo "groovyc_wrapper: could not locate bin/groovyc under \$PWD ($(pwd))" >&2
    exit 1
fi

# --- @argfile expansion ----------------------------------------------------
ARGS=()
if [ "$#" -eq 1 ] && [ "${1#@}" != "$1" ]; then
    ARGFILE="${1#@}"
    while IFS= read -r line || [ -n "$line" ]; do
        ARGS+=("$line")
    done < "$ARGFILE"
else
    ARGS=("$@")
fi

# --- Output redirection: `-d <X.jar>` → temp dir + `jar cf` -------------
# Scan the args for `-d <path>`. If `<path>` ends with `.jar`, redirect to a
# temp directory and post-pack with the JDK's `jar` tool.
OUTPUT_JAR=""
TMP_CLASSES_DIR=""
NEW_ARGS=()
i=0
while [ $i -lt ${#ARGS[@]} ]; do
    arg="${ARGS[$i]}"
    if [ "$arg" = "-d" ] && [ $((i + 1)) -lt ${#ARGS[@]} ]; then
        dest="${ARGS[$((i + 1))]}"
        case "$dest" in
            *.jar)
                OUTPUT_JAR="$dest"
                TMP_CLASSES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/groovyc_classes.XXXXXX")"
                NEW_ARGS+=("-d" "$TMP_CLASSES_DIR")
                i=$((i + 2))
                continue
                ;;
        esac
    fi
    NEW_ARGS+=("$arg")
    i=$((i + 1))
done

# --- Invoke groovyc --------------------------------------------------------
"$GROOVYC" "${NEW_ARGS[@]}"

# --- Pack temp classes dir into the requested jar -------------------------
if [ -n "$OUTPUT_JAR" ]; then
    if [ -z "${JAVA_HOME:-}" ]; then
        echo "groovyc_wrapper: JAVA_HOME is empty; cannot package classes into $OUTPUT_JAR" >&2
        exit 1
    fi
    JAR_TOOL="$JAVA_HOME/bin/jar"
    if [ ! -x "$JAR_TOOL" ]; then
        echo "groovyc_wrapper: \$JAVA_HOME/bin/jar not found at $JAR_TOOL" >&2
        exit 1
    fi
    # `jar cf <out> -C <dir> .` produces a jar of the directory contents.
    # Determinism (mtimes, ordering) is normalized by the downstream
    # singlejar action; this jar is an intermediate artifact.
    "$JAR_TOOL" cf "$OUTPUT_JAR" -C "$TMP_CLASSES_DIR" .
    rm -rf "$TMP_CLASSES_DIR"
fi

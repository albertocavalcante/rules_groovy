# Copyright 2026-present Alberto Cavalcante. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Hermetic compile and test-launcher actions for Groovy.

`compile_groovy` and the test-launcher helpers replace the upstream
`_groovy_jar`'s `ctx.actions.run_shell` + label-pinned SDK with
toolchain-resolved `ctx.actions.run` actions.

Hermeticity checkpoints:

  * No `ctx.actions.run_shell` for compile actions.
  * No `use_default_shell_env = True` anywhere.
  * `JAVA_HOME` passed explicitly from the resolved JDK runtime toolchain.
  * No reliance on host `$PATH`, `$GROOVY_HOME`, or `which groovyc`.
  * Param files always (`ctx.actions.args().use_param_file(..., use_always = True)`).
  * Packaging via `singlejar` from `rules_java`'s Java toolchain
    (`--add_missing_directories` gives directory entries in the output jar,
    matching `java_library` parity for `ClassLoader.getResource("pkg/")`).
  * Mnemonics on every action (`Groovyc`, `GroovySingleJar`).

The functions exposed here are consumed by `groovy/groovy.bzl`'s public rules.
"""

load("@rules_java//java:defs.bzl", "JavaInfo")

# Toolchain-type labels. Centralized so the `toolchains = [...]` attribute on
# each public rule and the lookups here stay in sync.
GROOVY_TOOLCHAIN_TYPE = "//groovy:toolchain_type"
JDK_RUNTIME_TOOLCHAIN_TYPE = "@bazel_tools//tools/jdk:runtime_toolchain_type"
JAVA_TOOLCHAIN_TYPE = "@bazel_tools//tools/jdk:toolchain_type"

REQUIRED_TOOLCHAINS = [
    GROOVY_TOOLCHAIN_TYPE,
    JDK_RUNTIME_TOOLCHAIN_TYPE,
    JAVA_TOOLCHAIN_TYPE,
]

def _groovy_info(ctx):
    return ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info

def _java_runtime(ctx):
    return ctx.toolchains[JDK_RUNTIME_TOOLCHAIN_TYPE].java_runtime

def _java_toolchain(ctx):
    # Bazel 9 / rules_java exposes the JavaToolchainInfo as the `.java` field
    # on the toolchain provided by @bazel_tools//tools/jdk:toolchain_type.
    # `single_jar` is the `singlejar` executable used for deterministic JAR
    # packaging (handles META-INF/services merge, --add_missing_directories,
    # --normalize, etc.) — the canonical replacement for the upstream
    # @bazel_tools//tools/zip:zipper invocation (ISSUE-041).
    return ctx.toolchains[JAVA_TOOLCHAIN_TYPE].java

def _jar_path_or_none(f):
    """`Args.add_joined`/`add_all` `map_each` callback: keep jars, drop everything else.

    Used to lazily filter classpath depsets at command-line construction
    time so we never flatten a depset just to filter it (Bazel perf doc:
    "avoid any flattening of depsets except for debugging purposes").
    """
    return f.path if f.path.endswith(".jar") else None

def _deps_classpath(deps):
    """Build a depset[File] classpath from a list of dep targets.

    Accepts either JavaInfo-providing targets (preferred — pulls
    `transitive_runtime_jars`) or bare File-providing targets. Bare-file
    deps may contribute non-jar files alongside jars; consumers filter to
    `.jar` lazily at command-line construction via the
    `_jar_path_or_none` `map_each` callback. This keeps the depset
    purely transitive — no `to_list()` flatten just to drop non-jars
    (Bazel perf doc).
    """
    java_info_jars = [
        dep[JavaInfo].transitive_runtime_jars
        for dep in deps
        if JavaInfo in dep
    ]
    non_java_file_depsets = [
        dep.files
        for dep in deps
        if JavaInfo not in dep
    ]
    return depset(transitive = java_info_jars + non_java_file_depsets)

def _toolchain_dep_provider_jars(ctx):
    """Every `GroovyDepsInfo.java_info.transitive_runtime_jars` from the toolchain.

    The module extension wires JUnit / Spock / Jupiter / Platform jars on
    the toolchain as `groovy_deps(dep_name = "junit_runner", ...)` etc.
    Folding them into both compile and runtime classpaths means
    `groovy_junit_test`, `groovy_junit5_test`, and `spock_test` no longer
    need to add literal `@junit_artifact` / `@spock_artifact` labels to
    their generated `groovy_library`'s `deps` — the toolchain owns the
    wiring (ISSUE-061).

    The cost on a non-test `groovy_library` compile is some extra jars on
    the compile classpath; JVM compilation is order-independent and
    unused jars do not affect output. The benefit is the test-macro
    surface stays free of hardcoded compat-repo labels.
    """
    transitive = []
    for dep in ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].deps:
        if dep.java_info != None:
            transitive.append(dep.java_info.transitive_runtime_jars)
    return depset(transitive = transitive)

def toolchain_deps_by_name(ctx, names):
    """Pick `GroovyDepsInfo` bundles off the toolchain by logical name.

    Returns a list of `JavaInfo` in the same order as `names`. Fails with
    a clear message if any requested name is not wired on the resolved
    toolchain (e.g. asking for `"junit_api"` on a JUnit-4 toolchain).

    Useful for rules that need a specific subset of the toolchain's test
    framework deps (vs. consuming the whole set via
    `_toolchain_dep_provider_jars`).
    """
    deps_info_list = ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].deps
    by_name = {info.name: info.java_info for info in deps_info_list}
    missing = [n for n in names if n not in by_name]
    if missing:
        fail("Toolchain missing required dep_providers: {} (have: {})".format(
            missing,
            sorted(by_name.keys()),
        ))
    return [by_name[n] for n in names]

def compile_groovy(ctx, srcs, deps, output_jar):
    """Compile `.groovy` (and optionally `.java`) sources to a deterministic JAR.

    Args:
      ctx:        the rule context.
      srcs:       list[File] of `.groovy` / `.java` source files.
      deps:       list[Target] of dep targets (JavaInfo-providing preferred).
      output_jar: declared output File for the final library JAR.

    Strategy:
      1. `groovyc -d <classes_jar>` writes a raw JAR directly (groovyc accepts
         a `.jar` path for `-d`; no separate `jar` invocation needed).
      2. `singlejar --sources <classes_jar> --add_missing_directories --normalize
         --exclude_build_data --output <output_jar>` produces the final,
         deterministic JAR with directory entries (ISSUE-051).

    Pattern cribbed from rules_kotlin's `_fold_jars_action`
    (`~/dev/refs/rules_kotlin/kotlin/internal/jvm/compile.bzl:256`).
    """
    groovy_info = _groovy_info(ctx)
    java_runtime = _java_runtime(ctx)
    singlejar = _java_toolchain(ctx).single_jar

    # Compile classpath includes:
    #   * Caller-supplied deps (transitive runtime jars / bare .jar files).
    #   * Every `GroovyDepsInfo` reachable from the toolchain (JUnit /
    #     Spock / Jupiter / Platform jars). Folding the toolchain
    #     test-framework jars in unconditionally means the test-rule
    #     macros (`groovy_junit_test`, `groovy_junit5_test`, `spock_test`)
    #     no longer need to thread `@junit_artifact` / `@spock_artifact`
    #     labels through to the generated `groovy_library`'s deps —
    #     ISSUE-061. The cost is some unused jars on a non-test
    #     groovy_library's compile classpath; JVM compilation is
    #     order-independent and unused jars do not affect output.
    classpath = depset(
        transitive = [_deps_classpath(deps), _toolchain_dep_provider_jars(ctx)],
    )
    raw_jar = ctx.actions.declare_file(ctx.label.name + "_classes.jar")

    # 1) groovyc → raw_jar
    groovyc_args = ctx.actions.args()
    groovyc_args.use_param_file("@%s", use_always = True)
    groovyc_args.set_param_file_format("multiline")
    groovyc_args.add("-d", raw_jar)

    # Classpath is built lazily from a depset and joined with the platform's
    # path separator. ":" matches the upstream behavior; Windows support
    # (ISSUE-027) is a v0.2 deliverable. `map_each = _jar_path_or_none`
    # drops any non-jar files contributed by bare-file deps in
    # `_deps_classpath` — the filter happens lazily here rather than
    # eagerly via `to_list()` in `_deps_classpath` (Bazel perf doc).
    groovyc_args.add_joined(
        "-cp",
        classpath,
        join_with = ":",
        map_each = _jar_path_or_none,
        # Empty classpath is legal (groovyc tolerates it). Omit the flag
        # entirely so we never emit a trailing `-cp ""`.
        omit_if_empty = True,
    )
    groovyc_args.add_all(srcs)

    ctx.actions.run(
        executable = groovy_info.groovyc,
        arguments = [groovyc_args],
        inputs = depset(
            srcs,
            transitive = [classpath, groovy_info.sdk_files, java_runtime.files],
        ),
        outputs = [raw_jar],
        env = {
            # Explicit JAVA_HOME; the groovyc launcher reads this. No
            # `use_default_shell_env`, no host PATH leak (ISSUE-040, ISSUE-042).
            "JAVA_HOME": java_runtime.java_home,
        },
        mnemonic = "Groovyc",
        progress_message = "Compiling Groovy sources for %{label}",
        # ISSUE-030 (Phase 3) will add worker support:
        # execution_requirements = {"supports-workers": "1"},
    )

    # 2) singlejar repackages → output_jar (deterministic, dir entries).
    sj_args = ctx.actions.args()
    sj_args.use_param_file("@%s", use_always = True)
    sj_args.set_param_file_format("multiline")
    sj_args.add("--normalize")
    sj_args.add("--exclude_build_data")
    sj_args.add("--add_missing_directories")
    sj_args.add("--output", output_jar)
    sj_args.add("--sources", raw_jar)

    ctx.actions.run(
        executable = singlejar,
        arguments = [sj_args],
        inputs = [raw_jar],
        outputs = [output_jar],
        mnemonic = "GroovySingleJar",
        progress_message = "Packaging Groovy jar for %{label}",
    )

def test_runtime_classpath(ctx, deps):
    """Build the runtime classpath depset for a groovy_test launcher.

    Includes:
      * The Groovy SDK's full file set (jars on the classpath; the SDK
        contains the groovy runtime + the AST transforms).
      * Every `GroovyDepsInfo` reachable from the toolchain (the JUnit /
        Spock / Jupiter / Platform jars wired by the module extension).
        Pulling these from the toolchain rather than caller `deps` means
        the JUnit 5 platform jars (jupiter-engine, platform-launcher,
        platform-engine, platform-commons, opentest4j, apiguardian-api)
        land on the test classpath without every macro re-listing them.
      * Caller-supplied deps' transitive runtime jars (JavaInfo) or raw .jars.
    """
    groovy_info = _groovy_info(ctx)

    toolchain_dep_jars = []
    for dep in ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].deps:
        if dep.java_info != None:
            toolchain_dep_jars.append(dep.java_info.transitive_runtime_jars)

    # Return the SDK's file depset transitively rather than flattening
    # it to filter for `.jar` (Bazel perf doc: avoid `to_list()`). The
    # launcher-script writer (`write_test_launcher`) must flatten the
    # final classpath anyway — it calls `ctx.actions.write` which can't
    # consume `ctx.actions.args` — and applies the `.jar` filter at
    # write-time, where the cost is bounded by the single flatten we
    # already pay.
    return depset(
        transitive = [groovy_info.sdk_files, _deps_classpath(deps)] + toolchain_dep_jars,
    )

# FQCN of JUnit 5's `ConsoleLauncher`. Compared against the toolchain's
# `runner_class` to pick the right test-launcher invocation shape. JUnit 4's
# `JUnitCore` is the implicit "everything else" branch.
JUNIT5_CONSOLE_LAUNCHER = "org.junit.platform.console.ConsoleLauncher"

def _runner_args(runner_class, classes):
    """Emit the runner-specific arg shape for the test launcher script.

    JUnit 4's `JUnitCore` takes one or more bare FQCNs as positional args.
    JUnit 5's `ConsoleLauncher` requires `--select-class <FQCN>` per spec.

    Branching lives here so the launcher template stays a single bash
    `exec` line per runner; the rule impl just hands off `runner_class`
    and the list of resolved FQCNs.
    """
    if runner_class == JUNIT5_CONSOLE_LAUNCHER:
        # `execute` is the explicit subcommand on JUnit Platform Console
        # Launcher 1.10+; the bare `--select-class` form is deprecated
        # (prints a warning that surfaces under `bazel test
        # --test_output=all`). `--disable-banner` keeps the tail focused
        # on results; `--details=tree` gives a human-readable test-tree
        # report.
        parts = ["execute", "--disable-banner", "--details=tree"]
        for cls in classes:
            parts.append("--select-class")
            parts.append(cls)
        return " ".join(parts)
    return " ".join(classes)

def write_test_launcher(ctx, classpath, classes, jvm_flags, runner_class):
    """Write the shell launcher script for `groovy_test`.

    The script is invoked via `ctx.outputs.executable` (Bazel's test runner
    runs it directly; no `ctx.actions.run_shell` is involved in this rule
    impl, satisfying the hermeticity checkpoint). JAVA_HOME comes from the
    resolved JDK runtime toolchain via the runfiles tree, not from the host
    environment.

    The runner-specific invocation shape (positional FQCNs for JUnitCore,
    `--select-class` per FQCN for ConsoleLauncher) is centralized in
    `_runner_args` so the launcher template stays a single bash `exec` line
    regardless of which runner is in play.

    Args:
      ctx:          the rule context.
      classpath:    depset[File] of classpath entries (short_paths used in
                    the script — runfiles-relative).
      classes:      list[string] of test class FQCNs.
      jvm_flags:    list[string] of `-D...` / `-X...` flags passed to JVM.
      runner_class: FQCN of the test runner main. `org.junit.runner.JUnitCore`
                    for JUnit 4 (positional FQCN args);
                    `org.junit.platform.console.ConsoleLauncher` for JUnit 5
                    and Spock 2.x (`--select-class <FQCN>` args).
    """
    java_runtime = _java_runtime(ctx)
    # The JDK runtime's java_executable_runfiles_path is the
    # runfiles-relative path to the JVM launcher; falls back to java_home
    # when running outside the runfiles tree. We use the explicit path so
    # the launcher never consults host PATH.
    java_bin = java_runtime.java_executable_runfiles_path

    # The classpath depset is flattened here because `ctx.actions.write`
    # cannot consume `ctx.actions.args` — the launcher script needs the
    # literal `:`-joined string inlined into bash. This is the one
    # legitimate `to_list()` call in the rule code (Bazel perf doc
    # carves out exactly this case). The `.jar` filter that used to live
    # in `test_runtime_classpath` and `_deps_classpath` now lives here:
    # the input depset can carry non-jar files (SDK metadata, bare-file
    # deps) and we drop them at the same flatten we're already paying.
    cp_str = ":".join([
        f.short_path
        for f in classpath.to_list()
        if f.path.endswith(".jar")
    ])
    flags_str = " ".join(jvm_flags)
    runner_args = _runner_args(runner_class, classes)

    script = (
        "#!/usr/bin/env bash\n" +
        "set -e\n" +
        "exec \"$(pwd)/{java_bin}\" {flags} -cp \"{cp}\" {runner} {args}\n"
    ).format(
        java_bin = java_bin,
        flags = flags_str,
        cp = cp_str,
        runner = runner_class,
        args = runner_args,
    )
    ctx.actions.write(
        output = ctx.outputs.executable,
        content = script,
        is_executable = True,
    )

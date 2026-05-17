# Copyright 2025-present Alberto Cavalcante. All rights reserved.
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

Chapter 4 of the v0.1.0 release narrative. Replaces `_groovy_jar`'s
`ctx.actions.run_shell` + label-pinned SDK with toolchain-resolved
`ctx.actions.run` actions.

Hermeticity checkpoints (see decisions/ADR-005, notes/design-hermetic.md):

  * No `ctx.actions.run_shell` for compile actions.
  * No `use_default_shell_env = True` anywhere.
  * `JAVA_HOME` passed explicitly from the resolved JDK runtime toolchain.
  * No reliance on host `$PATH`, `$GROOVY_HOME`, or `which groovyc`.
  * Param files always (`ctx.actions.args().use_param_file(..., use_always = True)`).
  * Packaging via `singlejar` from `rules_java`'s Java toolchain
    (`--add_missing_directories` gives directory entries in the output jar,
    fixing upstream ISSUE-051 / rules_groovy#52, #61).
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

def _deps_classpath(deps):
    """Build a depset[File] classpath from a list of dep targets.

    Accepts either JavaInfo-providing targets (preferred — pulls
    `transitive_runtime_jars`) or bare `.jar` File-providing targets.
    """
    java_info_jars = [
        dep[JavaInfo].transitive_runtime_jars
        for dep in deps
        if JavaInfo in dep
    ]
    non_java_files = []
    for dep in deps:
        if JavaInfo not in dep:
            non_java_files.extend([
                f
                for f in dep.files.to_list()
                if f.path.endswith(".jar")
            ])
    return depset(non_java_files, transitive = java_info_jars)

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

    classpath = _deps_classpath(deps)
    raw_jar = ctx.actions.declare_file(ctx.label.name + "_classes.jar")

    # 1) groovyc → raw_jar
    groovyc_args = ctx.actions.args()
    groovyc_args.use_param_file("@%s", use_always = True)
    groovyc_args.set_param_file_format("multiline")
    groovyc_args.add("-d", raw_jar)

    # Classpath is built lazily from a depset and joined with the platform's
    # path separator. ":" matches the upstream behavior; Windows support
    # (ISSUE-027) is a v0.2 deliverable.
    groovyc_args.add_joined(
        "-cp",
        classpath,
        join_with = ":",
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
      * Caller-supplied deps' transitive runtime jars (JavaInfo) or raw .jars.
    """
    groovy_info = _groovy_info(ctx)
    sdk_jars = [f for f in groovy_info.sdk_files.to_list() if f.path.endswith(".jar")]
    return depset(sdk_jars, transitive = [_deps_classpath(deps)])

def write_test_launcher(ctx, classpath, classes, jvm_flags, runner_class):
    """Write the shell launcher script for `groovy_test`.

    The script is invoked via `ctx.outputs.executable` (Bazel's test runner
    runs it directly; no `ctx.actions.run_shell` is involved in this rule
    impl, satisfying the hermeticity checkpoint). JAVA_HOME comes from the
    resolved JDK runtime toolchain via the runfiles tree, not from the host
    environment.

    Args:
      ctx:          the rule context.
      classpath:    depset[File] of classpath entries (short_paths used in
                    the script — runfiles-relative).
      classes:      list[string] of test class FQCNs.
      jvm_flags:    list[string] of `-D...` / `-X...` flags passed to JVM.
      runner_class: FQCN of the test runner main (e.g. JUnitCore).
    """
    java_runtime = _java_runtime(ctx)
    # The JDK runtime's java_executable_runfiles_path is the
    # runfiles-relative path to the JVM launcher; falls back to java_home
    # when running outside the runfiles tree. We use the explicit path so
    # the launcher never consults host PATH.
    java_bin = java_runtime.java_executable_runfiles_path

    cp_str = ":".join([f.short_path for f in classpath.to_list()])
    flags_str = " ".join(jvm_flags)
    classes_str = " ".join(classes)

    script = (
        "#!/usr/bin/env bash\n" +
        "set -e\n" +
        "exec \"$(pwd)/{java_bin}\" {flags} -cp \"{cp}\" {runner} {classes}\n"
    ).format(
        java_bin = java_bin,
        flags = flags_str,
        cp = cp_str,
        runner = runner_class,
        classes = classes_str,
    )
    ctx.actions.write(
        output = ctx.outputs.executable,
        content = script,
        is_executable = True,
    )

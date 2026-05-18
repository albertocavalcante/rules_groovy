# Copyright 2015-2024 The Bazel Authors. All rights reserved.
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

"""Public Groovy build rules.

This file defines the user-facing rules and macros — `groovy_library`,
`groovy_and_java_library`, `groovy_binary`, `groovy_test`,
`groovy_junit_test`, `groovy_junit5_test`, and `spock_test`. The
shape mirrors `rules_kotlin`'s `kt_jvm_library` — a single rule that
returns `JavaInfo` directly, accepts mixed `.groovy` + `.java` srcs
natively, and exposes the standard JVM-rule attribute surface
(`runtime_deps`, `exports`, `data`, `resources`, `neverlink`,
`plugins`).

All actions are hermetic and resolved through the toolchain registered
by the `groovy` module extension (see `extensions.bzl`).

Macro signatures preserve source-level compatibility with upstream
`bazelbuild/rules_groovy 0.0.6`; downstream BUILD files keep working
without edits.

Test rules pull JUnit / Spock / hamcrest / Jupiter / Platform artifacts
off the toolchain's `dep_providers` list (`GroovyDepsInfo.name`); the
legacy `@junit_artifact`, `@spock_artifact`, `@groovy_sdk_artifact`
literal labels no longer appear in this file (ISSUE-061).

Every wrapping macro in this file is a Bazel-8+ symbolic macro
(`macro(implementation = ..., attrs = ...)`); legacy `def`-based macros
were retired in ISSUE-067. Callers see unchanged signatures — the
migration is internal — and benefit from explicit `name`/`visibility`
parameters on each impl function plus macro-scoped visibility on every
internal scaffolding target the macro emits.
"""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_binary", "java_library")
load(
    "//groovy/private:actions.bzl",
    "GROOVY_TOOLCHAIN_TYPE",
    "REQUIRED_TOOLCHAINS",
    "compile_groovy",
    "test_runtime_classpath",
    "toolchain_deps_by_name",
    "write_test_launcher",
)
load("//groovy:toolchain.bzl", "GroovyLibraryInfo")

# ---------------------------------------------------------------------------
# groovy_library — single rule (not macro+rule). Returns JavaInfo directly,
# accepts mixed .groovy + .java srcs, and re-exports the Groovy SDK runtime
# jar via `exports` so any Java/Groovy consumer transparently sees
# `groovy.lang.GroovyObject` on both compile and runtime classpath.
# Shape mirrors rules_kotlin's `kt_jvm_library` (see jvm.bzl:371-410).
# ---------------------------------------------------------------------------

def _sdk_runtime_javainfo(ctx):
    """Build a JavaInfo wrapping the toolchain's Groovy SDK runtime jar.

    The SDK runtime jar (`groovy-X.Y.Z.jar`) carries `groovy.lang.*` types
    every compiled Groovy class implements. Wrapping it in a JavaInfo and
    folding into `groovy_library`'s `exports` means consumers see it on
    both compile and runtime classpath transparently — no `use_repo` on
    `@groovy_sdk_artifact` required downstream.
    """
    groovy_info = ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info
    return JavaInfo(
        output_jar = groovy_info.runtime_jar,
        compile_jar = groovy_info.runtime_jar,
    )

def _groovy_library_impl(ctx):
    output_jar = ctx.actions.declare_file("lib" + ctx.attr.name + ".jar")
    compile_groovy(
        ctx = ctx,
        srcs = ctx.files.srcs,
        deps = ctx.attr.deps,
        output_jar = output_jar,
    )

    sdk_runtime = _sdk_runtime_javainfo(ctx)
    java_info = JavaInfo(
        output_jar = output_jar,
        compile_jar = output_jar,
        deps = [d[JavaInfo] for d in ctx.attr.deps if JavaInfo in d],
        runtime_deps = [d[JavaInfo] for d in ctx.attr.runtime_deps if JavaInfo in d],
        # Re-export the SDK runtime jar so every consumer's compile +
        # runtime classpath includes `groovy.lang.GroovyObject` without
        # the consumer naming `@groovy_sdk_artifact//:groovy` explicitly.
        exports = [d[JavaInfo] for d in ctx.attr.exports if JavaInfo in d] + [sdk_runtime],
        neverlink = ctx.attr.neverlink,
    )
    return [
        DefaultInfo(files = depset([output_jar])),
        java_info,
        GroovyLibraryInfo(srcs = depset(ctx.files.srcs)),
    ]

groovy_library = rule(
    implementation = _groovy_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            allow_empty = False,
            doc = "Groovy and/or Java source files. Joint-compiled by groovyc.",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Compile- and runtime-classpath JavaInfo-providing deps.",
        ),
        "runtime_deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Runtime-only deps. Not on compile classpath.",
        ),
        "exports": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Deps re-exported to consumers of this library.",
        ),
        "data": attr.label_list(allow_files = True),
        "resources": attr.label_list(
            allow_files = True,
            doc = "Resource files. v0.1 folds these into a side `java_library` " +
                  "via the `groovy_test` / `groovy_junit_test` macros; for a " +
                  "`groovy_library` consumer, attach a separate `java_library` " +
                  "with `resources = [...]` and list it in `deps` until the " +
                  "v0.2 inline-resources support lands.",
        ),
        "neverlink": attr.bool(default = False),
        "plugins": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Java compiler plugins. Currently a no-op for Groovy; reserved.",
        ),
    },
    toolchains = REQUIRED_TOOLCHAINS,
    provides = [JavaInfo, GroovyLibraryInfo],
    doc = "Compile Groovy (and optionally Java) sources into a JVM library jar. " +
          "Returns `JavaInfo` directly; consumers may depend on this target " +
          "from `java_library`, `java_binary`, `java_test`, or another " +
          "`groovy_library` interchangeably.",
)

# ---------------------------------------------------------------------------
# _groovy_sdk_runtime — internal rule that exposes the toolchain's Groovy
# SDK runtime jar as a JavaInfo-providing target. Consumed by `groovy_binary`
# (a macro that wraps `java_binary`) so the binary's runtime classpath
# carries `groovy.lang.*` without naming `@groovy_sdk_artifact//:groovy`.
# Re-implementing the launcher is a v0.2 follow-up; until then this is the
# scoped-coupling fix for ISSUE-061's last hardcoded label.
# ---------------------------------------------------------------------------

def _groovy_sdk_runtime_impl(ctx):
    java_info = _sdk_runtime_javainfo(ctx)
    return [
        DefaultInfo(files = depset([ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info.runtime_jar])),
        java_info,
    ]

_groovy_sdk_runtime = rule(
    implementation = _groovy_sdk_runtime_impl,
    toolchains = [GROOVY_TOOLCHAIN_TYPE],
    provides = [JavaInfo],
    doc = "Internal: exposes the active Groovy toolchain's runtime jar as JavaInfo.",
)

# ---------------------------------------------------------------------------
# groovy_runtime — public rule exposing the toolchain's resolved Groovy SDK
# runtime jar as a `JavaInfo`-providing target. Stable label declared at
# `@rules_groovy//groovy:runtime` in `groovy/BUILD`.
#
# Reason for existing: the `groovy_*` rules in this set resolve the toolchain
# directly and pull `groovy_info.runtime_jar` off it. Downstream rules without
# toolchain access (e.g. plain `java_binary` running a Groovy program like
# CodeNarc) have no stable label to put Groovy on their runtime classpath
# after PR #21 collapsed the extension's `use_repo` exposure to just
# `groovy_toolchains`. This rule is that label.
#
# Per-version selection via the `groovy_version` build flag (PR #22) works
# transparently: the rule depends on `//groovy:toolchain_type` and Bazel's
# toolchain resolution machinery picks the matching toolchain.
# ---------------------------------------------------------------------------

def _groovy_runtime_impl(ctx):
    java_info = _sdk_runtime_javainfo(ctx)
    return [
        DefaultInfo(files = depset([ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info.runtime_jar])),
        java_info,
    ]

groovy_runtime = rule(
    implementation = _groovy_runtime_impl,
    toolchains = [GROOVY_TOOLCHAIN_TYPE],
    provides = [JavaInfo],
    doc = "Exposes the active Groovy toolchain's resolved runtime jar as a " +
          "`JavaInfo`-providing target. Useful for non-`groovy_*` rules " +
          "(e.g. plain `java_binary`) that need Groovy on their runtime " +
          "classpath — list `@rules_groovy//groovy:runtime` in `runtime_deps`. " +
          "Resolves via the active toolchain, including the per-version " +
          "selection driven by the `groovy_version` build flag (PR #22), so " +
          "the jar always matches the toolchain every other rule in this set " +
          "is using.",
)

# ---------------------------------------------------------------------------
# path_to_class — derive a Java FQCN from a test source path.
# ISSUE-002: slice on the source's actual extension instead of always `.groovy`.
# ISSUE-025: longest-prefix match against a caller-supplied `src_roots` list
# (default `["src/test/groovy", "src/test/java"]`) so tests can live under
# arbitrary directory roots, not just literal `src/test/groovy/` at the
# workspace root.
# ---------------------------------------------------------------------------

# Default source roots: Maven-style layout at the workspace root.
_DEFAULT_SRC_ROOTS = ["src/test/groovy", "src/test/java"]

def path_to_class(path, src_roots = _DEFAULT_SRC_ROOTS):
    """Convert a test source path to a Java/Groovy fully-qualified class name.

    Strips the longest matching prefix in `src_roots`, then drops the
    `.groovy` or `.java` extension, then converts `/` to `.`.

    With the default `src_roots`:

      * `src/test/groovy/<pkg>/<Cls>.groovy` → `<pkg>.<Cls>`
      * `src/test/java/<pkg>/<Cls>.java`     → `<pkg>.<Cls>`
      * `src/test/java/<pkg>/<Cls>.groovy`   → `<pkg>.<Cls>`  (Groovy under java/
                                                              is legal — groovyc
                                                              accepts mixed sources)

    Custom roots — e.g. `src_roots = ["example/foo/src/test/groovy"]` —
    work the same way; the longest matching root wins so nested layouts
    behave sensibly.

    Fails loudly when no root matches, or when the source's extension is
    not `.groovy` / `.java`.

    Args:
      path: Workspace-relative path to a test source file.
      src_roots: Source-root prefixes to try, longest first. Defaults to
        `["src/test/groovy", "src/test/java"]`.
    """
    sorted_roots = sorted(src_roots, key = lambda r: -len(r))
    for root in sorted_roots:
        prefix = root.rstrip("/") + "/"
        if path.startswith(prefix):
            stripped = path[len(prefix):]
            for ext in (".groovy", ".java"):
                if stripped.endswith(ext):
                    return stripped[:-len(ext)].replace("/", ".")
            fail("groovy_test source {} has an unsupported extension (expected .groovy or .java)".format(path))
    fail("groovy_test source {} does not live under any of src_roots = {}".format(path, src_roots))

# ---------------------------------------------------------------------------
# _groovy_test — internal test rule. Toolchain-resolved launcher writer +
# runfiles assembly. Wrapped by the public `groovy_test` symbolic macro
# below, and (transitively) by `groovy_junit_test`, `groovy_junit5_test`,
# and `spock_test`.
# ISSUE-003: returns [DefaultInfo(runfiles=...)] instead of legacy struct.
# ISSUE-061: implicit JUnit/Spock deps come off the toolchain's
# `dep_providers` list (logical names like `"junit_runner"`, `"spock"`),
# not literal `@junit_artifact` / `@spock_artifact` labels.
# ---------------------------------------------------------------------------

def _groovy_test_impl(ctx):
    # Resolve the runtime classpath off the toolchain + caller-supplied deps.
    # `test_runtime_classpath` pulls every `GroovyDepsInfo` reachable from
    # the toolchain too, so JUnit / Spock / Jupiter / Platform jars land on
    # the classpath without callers (or our own rule attrs) having to
    # re-list them.
    classpath = test_runtime_classpath(ctx, ctx.attr.deps)
    classes = [path_to_class(src.path, ctx.attr.src_roots) for src in ctx.files.srcs]

    # The runner main class is sourced from the toolchain so the module
    # extension owns the JUnit 4 / JUnit 5 selection. `groovy.testing(junit
    # = "5")` and the Spock-2 auto-promotion path both flip this to
    # `org.junit.platform.console.ConsoleLauncher`; everything else stays
    # on `org.junit.runner.JUnitCore` (the toolchain default).
    runner_class = ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info.runner_class

    write_test_launcher(
        ctx = ctx,
        classpath = classpath,
        classes = classes,
        jvm_flags = ctx.attr.jvm_flags,
        runner_class = runner_class,
    )

    # Runfiles: classpath jars + caller-declared data + JDK runtime (so the
    # `java` launcher embedded in the script resolves under bazel-bin/...
    # without consulting host PATH). `ctx.runfiles(transitive_files=...)`
    # accepts a depset directly — no `to_list()` flatten on `classpath`
    # (Bazel perf doc: avoid depset flattening except for debugging).
    # Both `classpath` and `java_runtime.files` are merged via a transitive
    # depset so neither is eagerly walked.
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    runfiles = ctx.runfiles(
        files = ctx.files.data,
        transitive_files = depset(transitive = [classpath, java_runtime.files]),
    )
    return [DefaultInfo(
        runfiles = runfiles,
        executable = ctx.outputs.executable,
    )]

_groovy_test = rule(
    implementation = _groovy_test_impl,
    attrs = {
        "srcs": attr.label_list(
            mandatory = True,
            # `.java` accepted so `groovy_junit_test` can pass Java test
            # sources through (ISSUE-002).
            allow_files = [".groovy", ".java"],
        ),
        "data": attr.label_list(allow_files = True),
        "jvm_flags": attr.string_list(),
        "deps": attr.label_list(allow_files = [".jar"]),
        "src_roots": attr.string_list(
            default = _DEFAULT_SRC_ROOTS,
            doc = "Source-root prefixes to strip from test source paths when " +
                  "deriving JUnit fully-qualified class names. Each `srcs` entry " +
                  "must live under one of these roots. Longest matching root wins. " +
                  "The default matches Maven-style layouts at the workspace root.",
        ),
    },
    test = True,
    toolchains = REQUIRED_TOOLCHAINS,
    doc = "Toolchain-resolved Groovy test rule. Internal — use `groovy_test`, " +
          "`groovy_junit_test`, `groovy_junit5_test`, or `spock_test`.",
)

# ---------------------------------------------------------------------------
# groovy_and_java_library — deprecated alias. Forwards to `groovy_library`,
# which now accepts mixed `.groovy` + `.java` srcs natively via groovyc
# joint compilation.
#
# Symbolic macro shape (ISSUE-067): `inherit_attrs` is not used because
# `groovy_library` is a user-defined rule loaded from the same .bzl file,
# and chaining symbolic-macro attr inheritance through it adds friction
# without payoff for a deprecated forwarder. The alias accepts the same
# attrs `groovy_library` accepts via the explicit list below.
# ---------------------------------------------------------------------------

def _groovy_and_java_library_impl(
        name,
        visibility,
        srcs,
        deps,
        runtime_deps,
        exports,
        data,
        resources,
        neverlink,
        plugins,
        **kwargs):
    groovy_library(
        name = name,
        visibility = visibility,
        srcs = srcs,
        deps = deps,
        runtime_deps = runtime_deps,
        exports = exports,
        data = data,
        resources = resources,
        neverlink = neverlink,
        plugins = plugins,
        **kwargs
    )

groovy_and_java_library = macro(
    implementation = _groovy_and_java_library_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "List of `.groovy` and/or `.java` source files.",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Compile- and runtime-classpath JavaInfo-providing deps.",
        ),
        "runtime_deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Runtime-only deps. Not on compile classpath.",
        ),
        "exports": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Deps re-exported to consumers of this library.",
        ),
        "data": attr.label_list(allow_files = True),
        "resources": attr.label_list(allow_files = True),
        "neverlink": attr.bool(),
        "plugins": attr.label_list(providers = [[JavaInfo]]),
    },
    inherit_attrs = "common",
    doc = """Deprecated alias for `groovy_library`.

`groovy_library` now accepts mixed `.groovy` and `.java` srcs natively
via joint compilation through groovyc; there is no behavioral
difference between calling `groovy_library(...)` and
`groovy_and_java_library(...)`. This alias exists only for
source-level compatibility with upstream `bazelbuild/rules_groovy
0.0.6` BUILD files.

Deprecated: use `groovy_library` directly. This alias is removed in v0.2.0.
""",
)

# ---------------------------------------------------------------------------
# groovy_binary — symbolic macro wrapping rules_java's `java_binary`.
#
# The coupling is scoped and documented; re-implementing the launcher
# (Linux/Windows/coverage) is a v0.2 follow-up if needed.
#
# The runtime Groovy SDK jar is added via a hidden `_groovy_sdk_runtime`
# target rather than a literal `@groovy_sdk_artifact//:groovy` label so
# the rules' own `groovy/groovy.bzl` stays free of legacy compat-repo
# names (ISSUE-061).
#
# `inherit_attrs = native.java_binary` gives this macro the full set of
# `java_binary` attrs (`jvm_flags`, `data`, `env`, `args`, `main_class`,
# `resources`, `output_licenses`, `stamp`, `launcher`, ...) for free.
# Inherited attrs the macro overrides internally are nulled out: `srcs`
# (we joint-compile them into a generated `groovy_library`), `runtime_deps`
# (we build the list from the SDK-runtime helper + our `deps`), and `deps`
# (callers pass deps via this macro's `deps`, which flow through to the
# generated `groovy_library` or to the binary's `runtime_deps`).
# ---------------------------------------------------------------------------

def _groovy_binary_impl(
        name,
        visibility,
        srcs,
        deps,
        main_class,
        jvm_flags,
        args,
        data,
        env,
        resources,
        stamp,
        launcher,
        classpath_resources,
        deploy_manifest_lines,
        use_testrunner,
        **kwargs):
    sdk_runtime = name + "_groovy_sdk_runtime"
    _groovy_sdk_runtime(
        name = sdk_runtime,
        testonly = kwargs.get("testonly"),
    )
    all_runtime_deps = [":" + sdk_runtime]
    if srcs:
        lib = name + "_lib"
        groovy_library(
            name = lib,
            srcs = srcs,
            testonly = kwargs.get("testonly"),
            deps = deps,
        )
        all_runtime_deps.append(":" + lib)
    elif deps:
        # When srcs is empty the caller's deps carry the main class; flow
        # them through as runtime_deps so the launcher's classpath
        # resolves the entry point.
        all_runtime_deps.extend(deps)

    # Pass through only the `java_binary` attrs the caller actually set.
    # `inherit_attrs = native.java_binary` would be the textbook fit, but
    # in practice `rules_java`'s exported `java_binary` is a legacy
    # `def`-based wrapper macro — it has no `rule()` / `macro()` symbol
    # whose attrs Bazel can introspect, and `native.java_binary`'s
    # inheritable attr surface comes back empty. We declare the
    # `java_binary` attrs we care about explicitly below and forward only
    # the ones the caller set (`None` means "omitted"); see the PR-25
    # notes for the surfaced gap.
    binary_kwargs = {}
    if main_class != None:
        binary_kwargs["main_class"] = main_class
    if jvm_flags != None:
        binary_kwargs["jvm_flags"] = jvm_flags
    if args != None:
        binary_kwargs["args"] = args
    if data != None:
        binary_kwargs["data"] = data
    if env != None:
        binary_kwargs["env"] = env
    if resources != None:
        binary_kwargs["resources"] = resources
    if stamp != None:
        binary_kwargs["stamp"] = stamp
    if launcher != None:
        binary_kwargs["launcher"] = launcher
    if classpath_resources != None:
        binary_kwargs["classpath_resources"] = classpath_resources
    if deploy_manifest_lines != None:
        binary_kwargs["deploy_manifest_lines"] = deploy_manifest_lines
    if use_testrunner != None:
        binary_kwargs["use_testrunner"] = use_testrunner

    # Merge our explicit binary attrs with the inherited common attrs from
    # **kwargs (testonly, tags, ...). The two dicts don't overlap since
    # the common-attr set is disjoint from the `java_binary` attrs we
    # declared above.
    merged = dict(binary_kwargs)
    for k, v in kwargs.items():
        if v != None:
            merged[k] = v
    java_binary(
        name = name,
        visibility = visibility,
        runtime_deps = all_runtime_deps,
        **merged
    )

groovy_binary = macro(
    implementation = _groovy_binary_impl,
    inherit_attrs = "common",
    attrs = {
        # Our own attrs: srcs are joint-compiled into a generated
        # `groovy_library` (or omitted if the caller's deps already carry
        # the main class). `deps` flow into that generated library, or, if
        # no srcs, into the binary's `runtime_deps`.
        "srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "List of `.groovy` and/or `.java` source files compiled " +
                  "into the binary. May be empty if `deps` already provides " +
                  "the entry point.",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Libraries on both the compile-time and runtime classpath.",
        ),
        # `java_binary` attrs we forward through. We declare them
        # explicitly rather than via `inherit_attrs = native.java_binary`
        # because `rules_java`'s `java_binary` is a legacy `def`-based
        # wrapper macro and `native.java_binary`'s inheritable attr surface
        # is empty under Bazel 9.1 (the example in /rules/macro-tutorial
        # uses `native.genrule`, which does expose its attrs — `java_binary`
        # does not). Documented in the PR-25 notes.
        "main_class": attr.string(
            doc = "Fully-qualified name of the entry-point class, or the name " +
                  "of a Groovy script class. See the " +
                  "[Groovy docs on scripts vs. classes]" +
                  "(https://www.groovy-lang.org/structure.html#_scripts_versus_classes).",
        ),
        "jvm_flags": attr.string_list(
            doc = "JVM flags embedded into the generated launcher script.",
        ),
        "args": attr.string_list(
            doc = "Default arguments passed to the binary when run via `bazel run`.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Runtime data files made available via Bazel runfiles.",
        ),
        "env": attr.string_dict(
            doc = "Environment variables set when the binary is run.",
        ),
        "resources": attr.label_list(
            allow_files = True,
            doc = "Resource files added to the binary's classpath.",
        ),
        "stamp": attr.int(
            default = -1,
            doc = "Whether to encode build information into the binary " +
                  "(`-1` = use `--stamp`, `0` = never, `1` = always).",
        ),
        "launcher": attr.label(
            doc = "Custom launcher binary used instead of the default JVM launcher.",
        ),
        "classpath_resources": attr.label_list(
            allow_files = True,
            doc = "Resources placed at the root of the binary's classpath.",
        ),
        "deploy_manifest_lines": attr.string_list(
            doc = "Lines added to the deploy jar's `META-INF/MANIFEST.MF`.",
        ),
        "use_testrunner": attr.bool(
            doc = "Use the JUnit test runner as the main class. " +
                  "Forwarded to `java_binary` verbatim.",
        ),
    },
    doc = """Builds an executable Groovy application.

Analogous to `java_binary` but accepts `.groovy` (and `.java`) sources.
Produces a runnable target you can launch with `bazel run`.

NOTE: this macro composes `rules_java`'s `java_binary` rule for the
runnable wrapper. That's a deliberate, scoped coupling — re-implementing
the launcher script (Linux/Windows/coverage) is non-trivial and a v0.2
follow-up if needed. The Groovy SDK runtime jar enters the binary's
classpath via a hidden `_groovy_sdk_runtime` helper rule so this macro
no longer needs to reference `@groovy_sdk_artifact//:groovy` by literal
label.

Common `java_binary` attributes (`main_class`, `jvm_flags`, `data`,
`env`, `args`, `stamp`, `launcher`, `resources`, `classpath_resources`,
`deploy_manifest_lines`, `use_testrunner`) are exposed explicitly and
forwarded to the underlying `java_binary`. The `runtime_deps` attribute
is owned by this macro — the generated `_groovy_sdk_runtime` target
plus, when `srcs` is non-empty, an internal `name + "_lib"`
`groovy_library` for the binary's own sources are wired through it
automatically. Internal scaffolding (the SDK-runtime and library
targets) lives at macro-scope visibility, not the binary's package
public surface.
""",
)

# ---------------------------------------------------------------------------
# groovy_test — public symbolic macro wrapping the internal `_groovy_test`
# rule, with an optional sidecar `java_library(resources = ...)` target
# created only when the caller passes `resources`.
# ---------------------------------------------------------------------------

def _groovy_test_macro_impl(
        name,
        visibility,
        deps,
        srcs,
        data,
        resources,
        jvm_flags,
        size,
        tags,
        src_roots,
        **kwargs):
    # Resources: v0.1 keeps the legacy side `java_library(resources = ...)`
    # target because folding classpath resources into the main `groovy_library`
    # jar requires either a `compile_groovy` extension or a small new
    # singlejar-merge action; both are v0.2 follow-ups. `java_library` is the
    # only `rules_java` usage in this file other than `java_binary` (for
    # `groovy_binary`). When `resources` is empty (the common case in the
    # `examples/` matrix) no `java_library` target is created and the macro
    # body avoids the `rules_java` macro entirely.
    # `deps` may be a select() under symbolic-macro semantics; preserve
    # it as-is and use `+` for concatenation, which handles selects.
    all_deps = deps or []
    # Symbolic-macro non-mandatory `attr.label_list` values arrive as
    # `None` when the caller omits them — including for explicit attrs
    # whose nominal default is `[]`. `resources` is non-configurable on
    # this macro (we read it during loading-phase to decide whether to
    # emit the sidecar `java_library`), so a plain truthiness check is
    # safe and avoids the `select()`-on-len pitfall.
    if resources:
        java_library(
            name = name + "-resources",
            resources = resources,
            testonly = 1,
        )
        all_deps = all_deps + [name + "-resources"]

    _groovy_test(
        name = name,
        visibility = visibility,
        size = size,
        tags = tags,
        srcs = srcs,
        deps = all_deps,
        data = data,
        jvm_flags = jvm_flags,
        src_roots = src_roots,
        **kwargs
    )

groovy_test = macro(
    implementation = _groovy_test_macro_impl,
    inherit_attrs = "common",
    attrs = {
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Libraries on both compile-time and runtime classpath. " +
                  "Accepts `groovy_library`, `java_library`, and `.jar` labels.",
        ),
        "srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "List of `.groovy` / `.java` source files whose names map to " +
                  "JUnit test classes.",
        ),
        "data": attr.label_list(
            allow_files = True,
            doc = "Runtime data files made available via Bazel runfiles.",
        ),
        "resources": attr.label_list(
            allow_files = True,
            configurable = False,
            doc = "Files packaged into a side `java_library` and added to the " +
                  "test classpath (useful for classpath-resource lookups).",
        ),
        "jvm_flags": attr.string_list(
            doc = "Flags embedded into the generated test launcher script.",
        ),
        "size": attr.string(
            default = "medium",
            configurable = False,
            doc = "Bazel test size — `small`, `medium`, `large`, or `enormous`. " +
                  "Defaults to `medium`.",
        ),
        "src_roots": attr.string_list(
            default = _DEFAULT_SRC_ROOTS,
            doc = "Source-root prefixes used to derive each test's FQCN. " +
                  "Defaults to `[\"src/test/groovy\", \"src/test/java\"]`. " +
                  "Longest matching root wins.",
        ),
    },
    doc = """Runs Groovy tests under the toolchain-selected JUnit runner.

Source filenames are converted to fully-qualified class names by
stripping the longest matching prefix in `src_roots`, then dropping
the `.groovy` / `.java` extension. Each derived class is passed to the
runner main class (`org.junit.runner.JUnitCore` for JUnit 4 toolchains,
`org.junit.platform.console.ConsoleLauncher` for JUnit 5 ones — the
active toolchain owns the choice) at execution time.

The default `src_roots` matches Maven-style layouts at the workspace
root (`src/test/groovy`, `src/test/java`). Override it to host tests
under arbitrary directory trees — e.g. `["example/foo/src/test/groovy"]`
— without rewriting `groovy/groovy.bzl`.

For convenience wrappers around JUnit/Spock that also handle library
splitting, see `groovy_junit_test`, `groovy_junit5_test`, and
`spock_test`.

JUnit / Spock jars land on the test classpath through the active
toolchain's `dep_providers` (logical names like `"junit_runner"`,
`"spock"`); the test rules no longer carry literal `@junit_artifact`
/ `@spock_artifact` labels (ISSUE-061).
""",
)

# ---------------------------------------------------------------------------
# groovy_junit_test — JUnit-4-driven Groovy tests. Splits inputs into a
# test-only library + a `groovy_test` target. The library lives at
# macro-scope visibility (no callers reach into `name + "-groovylib"`).
# ---------------------------------------------------------------------------

def _groovy_junit_test_impl(
        name,
        visibility,
        tests,
        deps,
        groovy_srcs,
        java_srcs,
        data,
        resources,
        jvm_flags,
        size,
        tags,
        src_roots,
        **kwargs):
    if len(tests) == 0:
        fail("Must provide at least one file in tests")

    # `groovy_library` now accepts mixed `.groovy` + `.java` srcs natively
    # via groovyc joint compilation, so the legacy split into a sidecar
    # `java_library` for `java_srcs` collapses into a single
    # `groovy_library` call. JUnit jars come from the toolchain's
    # `dep_providers`; the SDK runtime jar is re-exported through the
    # generated library's `JavaInfo.exports`.
    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = tests + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
    # `deps` may be a select-wrapped list under symbolic-macro semantics;
    # plain `+` concatenation preserves the select.
    test_deps = (deps or []) + [groovylib]

    groovy_test(
        name = name,
        visibility = visibility,
        deps = test_deps,
        srcs = tests,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
        **kwargs
    )

groovy_junit_test = macro(
    implementation = _groovy_junit_test_impl,
    inherit_attrs = "common",
    attrs = {
        "tests": attr.label_list(
            allow_files = [".groovy", ".java"],
            configurable = False,
            doc = "`.groovy` / `.java` files that define JUnit test classes " +
                  "(the runnable specs).",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Libraries on both compile-time and runtime classpath.",
        ),
        "groovy_srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "Additional `.groovy` / `.java` helper sources compiled into " +
                  "a supporting `groovy_library`.",
        ),
        "java_srcs": attr.label_list(
            allow_files = [".java"],
            doc = "Additional `.java` helper sources compiled into a " +
                  "supporting `java_library`.",
        ),
        "data": attr.label_list(allow_files = True),
        "resources": attr.label_list(allow_files = True, configurable = False),
        "jvm_flags": attr.string_list(),
        "size": attr.string(default = "small", configurable = False),
        "src_roots": attr.string_list(default = _DEFAULT_SRC_ROOTS),
    },
    doc = """Convenience macro for JUnit-4-driven Groovy tests with helper sources.

Splits inputs into a test-only library + a `groovy_test` target. Use
this when your tests share helper Groovy or Java types that aren't
themselves test specifications. JUnit jars come from the active
toolchain's `dep_providers`, not a literal `@junit_artifact` label
(ISSUE-061).

`tests` are the JUnit-runnable specs; `groovy_srcs` and `java_srcs`
are compiled into supporting libraries on the test classpath. The
generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.
""",
)

# ---------------------------------------------------------------------------
# groovy_junit5_test — JUnit 5 (Jupiter) variant of `groovy_junit_test`.
# Identical macro shape; the toolchain's `runner_class` resolves to
# `org.junit.platform.console.ConsoleLauncher` and Jupiter / Platform
# jars come off the toolchain's `dep_providers`.
# ---------------------------------------------------------------------------

def _groovy_junit5_test_impl(
        name,
        visibility,
        tests,
        deps,
        groovy_srcs,
        java_srcs,
        data,
        resources,
        jvm_flags,
        size,
        tags,
        src_roots,
        **kwargs):
    if len(tests) == 0:
        fail("Must provide at least one file in tests")

    # The Jupiter API jar lands on the test classpath via the toolchain's
    # `dep_providers` (logical name `"junit_api"`); `compile_groovy` adds
    # every reachable `GroovyDepsInfo.java_info` to the compile classpath
    # via the same toolchain path the test launcher uses for its runtime
    # classpath. `groovy_library` accepts mixed `.groovy` + `.java` srcs
    # natively so `java_srcs` folds into the single library call.
    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = tests + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
    # `deps` may be a select-wrapped list under symbolic-macro semantics;
    # plain `+` concatenation preserves the select.
    test_deps = (deps or []) + [groovylib]

    groovy_test(
        name = name,
        visibility = visibility,
        deps = test_deps,
        srcs = tests,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
        **kwargs
    )

groovy_junit5_test = macro(
    implementation = _groovy_junit5_test_impl,
    inherit_attrs = "common",
    attrs = {
        "tests": attr.label_list(
            allow_files = [".groovy", ".java"],
            configurable = False,
            doc = "`.groovy` files that define JUnit 5 (Jupiter) test classes.",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Libraries on both compile-time and runtime classpath.",
        ),
        "groovy_srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "Additional `.groovy` helper sources compiled into a " +
                  "supporting `groovy_library`.",
        ),
        "java_srcs": attr.label_list(
            allow_files = [".java"],
            doc = "Additional `.java` helper sources compiled into a " +
                  "supporting `java_library`.",
        ),
        "data": attr.label_list(allow_files = True),
        "resources": attr.label_list(allow_files = True, configurable = False),
        "jvm_flags": attr.string_list(),
        "size": attr.string(default = "small", configurable = False),
        "src_roots": attr.string_list(default = _DEFAULT_SRC_ROOTS),
    },
    doc = """Convenience macro for JUnit 5 (Jupiter)-driven Groovy tests.

Mirrors `groovy_junit_test`'s signature but routes the runtime
through `org.junit.platform.console.ConsoleLauncher`. Jupiter API,
Jupiter Engine, and the full Platform launcher classpath
(platform-launcher / engine / commons, opentest4j, apiguardian-api)
come off the active toolchain's `dep_providers` (logical names
`"junit_api"`, `"junit_engine"`, `"junit_platform_launcher"`, etc.).

Wiring this on top of a JUnit-4-only toolchain fails at runtime
(ConsoleLauncher isn't on the classpath). Either declare
`groovy.testing(junit = "5")` in your `MODULE.bazel`, or accept the
Groovy-4 default which auto-promotes to JUnit 5 because Spock 2.x
requires it.

The generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.
""",
)

# ---------------------------------------------------------------------------
# spock_test — Spock specifications. Same macro shape as the JUnit wrappers;
# the toolchain's `runner_class` flips to `ConsoleLauncher` automatically
# under Spock 2.x toolchains (Groovy 3.0 / 4.0), staying on `JUnitCore`
# under Spock 1.3 toolchains (Groovy 2.5).
# ---------------------------------------------------------------------------

def _spock_test_impl(
        name,
        visibility,
        specs,
        deps,
        groovy_srcs,
        java_srcs,
        data,
        resources,
        jvm_flags,
        size,
        tags,
        src_roots,
        **kwargs):
    if len(specs) == 0:
        fail("Must provide at least one file in specs")

    # Single `groovy_library` for specs + helper srcs (Groovy and Java
    # both compile through groovyc joint compilation now). Spock +
    # JUnit jars come off the toolchain's `dep_providers`.
    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = specs + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
    # `deps` may be a select-wrapped list under symbolic-macro semantics;
    # plain `+` concatenation preserves the select.
    test_deps = (deps or []) + [groovylib]

    groovy_test(
        name = name,
        visibility = visibility,
        deps = test_deps,
        srcs = specs,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
        **kwargs
    )

spock_test = macro(
    implementation = _spock_test_impl,
    inherit_attrs = "common",
    attrs = {
        "specs": attr.label_list(
            allow_files = [".groovy"],
            configurable = False,
            doc = "`.groovy` files defining Spock specifications.",
        ),
        "deps": attr.label_list(
            providers = [[JavaInfo]],
            doc = "Libraries on both compile-time and runtime classpath.",
        ),
        "groovy_srcs": attr.label_list(
            allow_files = [".groovy", ".java"],
            doc = "Additional `.groovy` helper sources compiled into a " +
                  "supporting `groovy_library`.",
        ),
        "java_srcs": attr.label_list(
            allow_files = [".java"],
            doc = "Additional `.java` helper sources compiled into a " +
                  "supporting `java_library`.",
        ),
        "data": attr.label_list(allow_files = True),
        "resources": attr.label_list(allow_files = True, configurable = False),
        "jvm_flags": attr.string_list(),
        "size": attr.string(default = "small", configurable = False),
        "src_roots": attr.string_list(default = _DEFAULT_SRC_ROOTS),
    },
    doc = """Convenience macro for Spock specifications.

Wraps `specs` in a test-only `groovy_library` and emits a
`groovy_test`. The Spock jar version is selected by the active
toolchain's Groovy major.minor — Groovy 2.5 pulls Spock 1.3 (JUnit
4 path), Groovy 3.0 / 4.0 pull Spock 2.3 (JUnit 5 Platform path).
The launcher invocation auto-routes through `JUnitCore` or
`ConsoleLauncher` based on the toolchain's resolved `runner_class`;
the macro itself stays signature-stable.

Spock and JUnit jars come off the active toolchain's `dep_providers`
(logical names `"spock"`, `"junit_runner"`, `"junit_api"`, etc.); no
literal `@junit_artifact` / `@spock_artifact` labels appear in this
file (ISSUE-061).

The generated `name + "-groovylib"` target lives at macro-scope
visibility — callers do not reach into it directly.
""",
)

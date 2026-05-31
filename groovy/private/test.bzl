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

"""Test rules and macros — `groovy_test`, `groovy_junit_test`,
`groovy_junit5_test`, `spock_test`, and the `path_to_class` FQCN helper.

Every public test wrapper is a Bazel-8+ symbolic macro wrapping the
internal `_groovy_test` rule. Toolchain-resolved launcher writer +
runfiles assembly. JUnit / Spock jars come off the toolchain's
`dep_providers` list (logical names like `"junit_runner"`, `"spock"`),
not literal `@junit_artifact` / `@spock_artifact` labels (ISSUE-061).
"""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_library")
load(
    "//groovy/private:actions.bzl",
    "GROOVY_TOOLCHAIN_TYPE",
    "REQUIRED_TOOLCHAINS",
    "test_runtime_classpath",
    "write_test_launcher",
)
load("//groovy/private:library.bzl", "groovy_library")

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

    Returns:
      The fully-qualified Java/Groovy class name as a string (e.g.
      `"com.example.MyTest"`).
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
# ---------------------------------------------------------------------------

def _groovy_test_impl(ctx):
    # Resolve the runtime classpath off the toolchain + caller-supplied deps.
    classpath = test_runtime_classpath(ctx, ctx.attr.deps)
    classes = [path_to_class(src.path, ctx.attr.src_roots) for src in ctx.files.srcs]

    # The runner main class is sourced from the toolchain so the module
    # extension owns the JUnit 4 / JUnit 5 selection.
    runner_class = ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info.runner_class

    write_test_launcher(
        ctx = ctx,
        classpath = classpath,
        classes = classes,
        jvm_flags = ctx.attr.jvm_flags,
        runner_class = runner_class,
    )

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
    # target. When `resources` is empty no `java_library` target is created.
    all_deps = deps or []
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
— without rewriting the call sites.

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

    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = tests + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
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

    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = tests + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
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

    groovylib = name + "-groovylib"
    groovy_library(
        name = groovylib,
        srcs = specs + groovy_srcs + java_srcs,
        testonly = 1,
        deps = deps,
    )
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

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

This file defines the user-facing macros — `groovy_library`,
`groovy_and_java_library`, `groovy_binary`, `groovy_test`,
`groovy_junit_test`, and `spock_test` — plus the underlying rules that
implement them. All actions are hermetic and resolved through the
toolchain registered by the `groovy` module extension (see
`extensions.bzl`).

Macro signatures preserve source-level compatibility with upstream
`bazelbuild/rules_groovy 0.0.6`; downstream BUILD files keep working
without edits.
"""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_binary", "java_import", "java_library")
load("//groovy/private:actions.bzl", "REQUIRED_TOOLCHAINS", "compile_groovy", "test_runtime_classpath", "write_test_launcher")

# ---------------------------------------------------------------------------
# groovy_jar — the underlying compile rule. Produces `libNAME.jar`.
# Toolchain-resolved, hermetic; no `_zipper`, no `_jdk`, no `_groovysdk`
# (ISSUE-001, ISSUE-040, ISSUE-041, ISSUE-042).
# ---------------------------------------------------------------------------

def _groovy_jar_impl(ctx):
    compile_groovy(
        ctx = ctx,
        srcs = ctx.files.srcs,
        deps = ctx.attr.deps,
        output_jar = ctx.outputs.class_jar,
    )
    return [DefaultInfo(files = depset([ctx.outputs.class_jar]))]

_groovy_jar = rule(
    implementation = _groovy_jar_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_empty = False,
            # `.java` is allowed here because groovyc accepts mixed-source
            # compilation (Groovy ↔ Java cross-references). `groovy_library`
            # passes only `.groovy`; `groovy_and_java_library` partitions and
            # routes `.java` through `java_library` instead.
            allow_files = [".groovy", ".java"],
        ),
        "deps": attr.label_list(
            allow_files = [".jar"],
        ),
    },
    outputs = {
        "class_jar": "lib%{name}.jar",
    },
    toolchains = REQUIRED_TOOLCHAINS,
    doc = "Compiles Groovy sources into a deterministic library JAR. " +
          "Internal — use `groovy_library` / `groovy_and_java_library`.",
)

# ---------------------------------------------------------------------------
# Public macros: library + binary
# ---------------------------------------------------------------------------

def groovy_library(name, srcs = [], testonly = 0, deps = [], **kwargs):
    """Builds a Groovy library jar.

    Analogous to `java_library`, but accepts `.groovy` sources instead of
    `.java`. The compiled jar is wrapped in a `java_import` so that Java
    rules can depend on it transparently — `java_library`, `java_binary`,
    and `java_test` all consume `groovy_library` targets via their `deps`
    attribute.

    Args:
      name: A unique name for this target.
      srcs: List of `.groovy` source files to compile.
      testonly: If `1`, the resulting `java_import` is testonly; only
        other testonly targets may depend on it. Defaults to `0`.
      deps: List of libraries or raw `.jar` files on the compile-time
        classpath. Accepts `groovy_library`, `java_library`,
        `groovy_and_java_library`, and `.jar` labels.
      **kwargs: Additional arguments forwarded to the wrapping
        `java_import` (e.g. `visibility`, `tags`, `runtime_deps`).
    """
    _groovy_jar(
        name = name + "-impl",
        srcs = srcs,
        testonly = testonly,
        deps = deps,
    )
    java_import(
        name = name,
        jars = [name + "-impl"],
        testonly = testonly,
        deps = deps,
        **kwargs
    )

def groovy_and_java_library(name, srcs = [], testonly = 0, deps = [], **kwargs):
    """Builds a mixed Groovy + Java library from a single source list.

    Splits `srcs` by extension into a `java_library` (`.java` files) and a
    Groovy compile (`.groovy` files), then bundles both into one
    `java_import`. The Groovy side depends on the Java side, so Groovy
    code may reference Java types but not vice-versa.

    Use this rule when Groovy and Java sources are tightly coupled and
    you don't want to maintain two BUILD targets by hand. For looser
    coupling, prefer two separate targets — one `groovy_library`, one
    `java_library` — with an explicit `deps` edge.

    Args:
      name: A unique name for this target.
      srcs: List of `.groovy` and `.java` source files.
      testonly: If `1`, the resulting `java_import` is testonly. Defaults
        to `0`.
      deps: List of libraries or raw `.jar` files on the compile-time
        classpath of both sub-libraries.
      **kwargs: Additional arguments forwarded to the wrapping
        `java_import`.
    """
    groovy_deps = deps
    jars = []

    # Put all .java sources in a java_library
    java_srcs = [src for src in srcs if src.endswith(".java")]
    if java_srcs:
        java_library(
            name = name + "-java",
            srcs = java_srcs,
            testonly = testonly,
            deps = deps,
        )
        groovy_deps = depset(groovy_deps + [name + "-java"])
        jars += ["lib" + name + "-java.jar"]

    # Put all .groovy sources in a groovy_library depending on the java_library
    groovy_srcs = [src for src in srcs if src.endswith(".groovy")]
    if groovy_srcs:
        _groovy_jar(
            name = name + "-groovy",
            srcs = groovy_srcs,
            testonly = testonly,
            deps = groovy_deps,
        )
        jars += ["lib" + name + "-groovy.jar"]

    # Output a java_import combining both libraries
    java_import(
        name = name,
        jars = jars,
        testonly = testonly,
        deps = deps,
        **kwargs
    )

def groovy_binary(name, main_class, srcs = [], testonly = 0, deps = [], **kwargs):
    """Builds an executable Groovy application.

    Analogous to `java_binary` but accepts `.groovy` sources. Produces a
    runnable target you can launch with `bazel run`. The Groovy runtime
    jar resolved by the active toolchain is added to `runtime_deps`
    automatically, so users don't have to depend on `@groovy_sdk_artifact`
    explicitly.

    Args:
      name: A unique name for this target.
      main_class: Fully-qualified name of the entry-point class, or the
        name of a Groovy script class. See the
        [Groovy docs on scripts vs. classes](https://www.groovy-lang.org/structure.html#_scripts_versus_classes).
      srcs: List of `.groovy` source files compiled into the binary. May
        be empty if `deps` already provides the entry point.
      testonly: If `1`, the binary is testonly. Defaults to `0`.
      deps: Libraries on both the compile-time and runtime classpath.
      **kwargs: Additional arguments forwarded to the underlying
        `java_binary` (e.g. `jvm_flags`, `visibility`, `data`).
    """
    all_deps = deps + ["@groovy_sdk_artifact//:groovy"]
    if srcs:
        groovy_library(
            name = name + "-lib",
            srcs = srcs,
            testonly = testonly,
            deps = deps,
        )
        all_deps += [name + "-lib"]
    java_binary(
        name = name,
        main_class = main_class,
        runtime_deps = all_deps,
        testonly = testonly,
        **kwargs
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
# groovy_test — toolchain-resolved test launcher.
# ISSUE-003: returns [DefaultInfo(runfiles=...)] instead of legacy struct.
# ---------------------------------------------------------------------------

def _groovy_test_impl(ctx):
    # Resolve the runtime classpath off the toolchain + caller-supplied deps.
    # `test_runtime_classpath` now pulls every `GroovyDepsInfo` reachable
    # from the toolchain too, so JUnit / Spock / Jupiter / Platform jars
    # land on the classpath without callers (or our own `_implicit_deps`)
    # having to re-list them. The literal `@junit_artifact` / `@spock_artifact`
    # labels still flow through `_implicit_deps` for the JUnit 4 / Spock 1.3
    # path; full ISSUE-061 cleanup is a follow-up.
    classpath = test_runtime_classpath(ctx, ctx.attr.deps + ctx.attr._implicit_deps)
    classes = [path_to_class(src.path, ctx.attr.src_roots) for src in ctx.files.srcs]

    # The runner main class is sourced from the toolchain so the module
    # extension owns the JUnit 4 / JUnit 5 selection. `groovy.testing(junit
    # = "5")` and the Spock-2 auto-promotion path both flip this to
    # `org.junit.platform.console.ConsoleLauncher`; everything else stays
    # on `org.junit.runner.JUnitCore` (the toolchain default).
    runner_class = ctx.toolchains["//groovy:toolchain_type"].groovy_info.runner_class

    write_test_launcher(
        ctx = ctx,
        classpath = classpath,
        classes = classes,
        jvm_flags = ctx.attr.jvm_flags,
        runner_class = runner_class,
    )

    # Runfiles: classpath jars + caller-declared data + JDK runtime (so the
    # `java` launcher embedded in the script resolves under bazel-bin/...
    # without consulting host PATH).
    java_runtime = ctx.toolchains["@bazel_tools//tools/jdk:runtime_toolchain_type"].java_runtime
    runfiles = ctx.runfiles(
        files = classpath.to_list() + ctx.files.data,
        transitive_files = java_runtime.files,
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
        "_implicit_deps": attr.label_list(default = [
            Label("@junit_artifact//jar"),
        ]),
    },
    test = True,
    toolchains = REQUIRED_TOOLCHAINS,
    doc = "Toolchain-resolved Groovy test rule. Internal — use `groovy_test`, " +
          "`groovy_junit_test`, or `spock_test`.",
)

def groovy_test(
        name,
        deps = [],
        srcs = [],
        data = [],
        resources = [],
        jvm_flags = [],
        size = "medium",
        tags = [],
        src_roots = _DEFAULT_SRC_ROOTS):
    """Runs Groovy tests under JUnit 4 (`JUnitCore`).

    Source filenames are converted to fully-qualified class names by
    stripping the longest matching prefix in `src_roots`, then dropping
    the `.groovy` / `.java` extension. Each derived class is passed to
    `org.junit.runner.JUnitCore` at execution time.

    The default `src_roots` matches Maven-style layouts at the workspace
    root (`src/test/groovy`, `src/test/java`). Override it to host tests
    under arbitrary directory trees — e.g. `["example/foo/src/test/groovy"]`
    — without rewriting `groovy/groovy.bzl`.

    For convenience wrappers around JUnit/Spock that also handle library
    splitting, see `groovy_junit_test` and `spock_test`.

    Args:
      name: A unique name for this target.
      deps: Libraries on both compile-time and runtime classpath.
        Accepts `groovy_library`, `java_library`,
        `groovy_and_java_library`, and `.jar` labels.
      srcs: List of `.groovy` source files whose names map to JUnit test
        classes.
      data: Runtime data files made available via Bazel runfiles.
      resources: Files packaged into a side `java_library` and added to
        the test classpath (useful for classpath-resource lookups).
      jvm_flags: Flags embedded into the generated test launcher script.
      size: Bazel test size — `small`, `medium`, `large`, or `enormous`.
        Defaults to `medium`.
      tags: Bazel test tags (e.g. `manual`, `requires-network`).
      src_roots: Source-root prefixes used to derive each test's FQCN.
        Defaults to `["src/test/groovy", "src/test/java"]`. Longest
        matching root wins.
    """

    # Create an extra jar to hold the resource files if any were specified
    all_deps = deps
    if resources:
        java_library(
            name = name + "-resources",
            resources = resources,
            testonly = 1,
        )
        all_deps += [name + "-resources"]

    _groovy_test(
        name = name,
        size = size,
        tags = tags,
        srcs = srcs,
        deps = all_deps,
        data = data,
        jvm_flags = jvm_flags,
        src_roots = src_roots,
    )

def groovy_junit_test(
        name,
        tests,
        deps = [],
        groovy_srcs = [],
        java_srcs = [],
        data = [],
        resources = [],
        jvm_flags = [],
        size = "small",
        tags = [],
        src_roots = _DEFAULT_SRC_ROOTS):
    """Convenience macro for JUnit-driven Groovy tests with helper sources.

    Splits inputs into a test-only library + a `groovy_test` target. Use
    this when your tests share helper Groovy or Java types that aren't
    themselves test specifications.

    `tests` are the JUnit-runnable specs; `groovy_srcs` and `java_srcs`
    are compiled into supporting libraries on the test classpath.

    Args:
      name: A unique name for this target.
      tests: `.groovy` files that define JUnit test classes (the
        runnable specs).
      deps: Libraries on both compile-time and runtime classpath.
      groovy_srcs: Additional `.groovy` helper sources compiled into a
        supporting `groovy_library`.
      java_srcs: Additional `.java` helper sources compiled into a
        supporting `java_library`.
      data: Runtime data files exposed via runfiles.
      resources: Files packaged into a side `java_library` and added to
        the test classpath.
      jvm_flags: Flags embedded into the generated test launcher script.
      size: Bazel test size. Defaults to `small`.
      tags: Bazel test tags.
      src_roots: Source-root prefixes forwarded to the underlying
        `groovy_test` for FQCN derivation. Defaults to
        `["src/test/groovy", "src/test/java"]`.
    """
    groovy_lib_deps = deps + ["@junit_artifact//jar"]
    test_deps = deps + ["@junit_artifact//jar"]

    if len(tests) == 0:
        fail("Must provide at least one file in tests")

    # Put all Java sources into a Java library
    if java_srcs:
        java_library(
            name = name + "-javalib",
            srcs = java_srcs,
            testonly = 1,
            deps = deps + ["@junit_artifact//jar"],
        )
        groovy_lib_deps += [name + "-javalib"]
        test_deps += [name + "-javalib"]

    # Put all tests and Groovy sources into a Groovy library
    groovy_library(
        name = name + "-groovylib",
        srcs = tests + groovy_srcs,
        testonly = 1,
        deps = groovy_lib_deps,
    )
    test_deps += [name + "-groovylib"]

    # Create a groovy test
    groovy_test(
        name = name,
        deps = test_deps,
        srcs = tests,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
    )

def groovy_junit5_test(
        name,
        tests,
        deps = [],
        groovy_srcs = [],
        java_srcs = [],
        data = [],
        resources = [],
        jvm_flags = [],
        size = "small",
        tags = [],
        src_roots = _DEFAULT_SRC_ROOTS):
    """Convenience macro for JUnit 5 (Jupiter)-driven Groovy tests.

    Mirrors `groovy_junit_test`'s signature but wires the compile classpath
    against JUnit 5 Jupiter (`@groovy_artifacts//:junit_api`) and lets the
    test rule pick up the full JUnit 5 Platform runtime (jupiter-engine,
    platform-launcher / engine / commons, opentest4j, apiguardian-api) from
    the active toolchain's `dep_providers` — no literal `@junit_artifact`
    refs in this path. The launcher invocation routes through
    `org.junit.platform.console.ConsoleLauncher` because the active
    toolchain's `runner_class` is set to ConsoleLauncher whenever the
    module extension resolved a JUnit 5 testing flavor.

    Wiring this on top of a JUnit-4-only toolchain fails at runtime
    (ConsoleLauncher isn't on the classpath). Either declare
    `groovy.testing(junit = "5")` in your `MODULE.bazel`, or accept the
    Groovy-4 default which auto-promotes to JUnit 5 because Spock 2.x
    requires it.

    Args:
      name: A unique name for this target.
      tests: `.groovy` files that define JUnit 5 (Jupiter) test classes.
      deps: Libraries on both compile-time and runtime classpath.
      groovy_srcs: Additional `.groovy` helper sources compiled into a
        supporting `groovy_library`.
      java_srcs: Additional `.java` helper sources compiled into a
        supporting `java_library`.
      data: Runtime data files exposed via runfiles.
      resources: Files packaged into a side `java_library` and added to
        the test classpath.
      jvm_flags: Flags embedded into the generated test launcher script.
      size: Bazel test size. Defaults to `small`.
      tags: Bazel test tags.
      src_roots: Source-root prefixes forwarded to the underlying
        `groovy_test` for FQCN derivation. Defaults to
        `["src/test/groovy", "src/test/java"]`.
    """

    # JUnit 5 API jar for compile-time annotations / assertions. Sourced
    # by alias from the @groovy_artifacts hub so the user's `*_label`
    # overrides on the testing tag take effect transparently.
    junit5_api = "@groovy_artifacts//:junit_api"

    groovy_lib_deps = deps + [junit5_api]
    test_deps = deps + [junit5_api]

    if len(tests) == 0:
        fail("Must provide at least one file in tests")

    if java_srcs:
        java_library(
            name = name + "-javalib",
            srcs = java_srcs,
            testonly = 1,
            deps = deps + [junit5_api],
        )
        groovy_lib_deps += [name + "-javalib"]
        test_deps += [name + "-javalib"]

    groovy_library(
        name = name + "-groovylib",
        srcs = tests + groovy_srcs,
        testonly = 1,
        deps = groovy_lib_deps,
    )
    test_deps += [name + "-groovylib"]

    groovy_test(
        name = name,
        deps = test_deps,
        srcs = tests,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
    )

def spock_test(
        name,
        specs,
        deps = [],
        groovy_srcs = [],
        java_srcs = [],
        data = [],
        resources = [],
        jvm_flags = [],
        size = "small",
        tags = [],
        src_roots = _DEFAULT_SRC_ROOTS):
    """Convenience macro for Spock specifications.

    Wraps `specs` in a test-only `groovy_library` with JUnit and Spock
    pinned on the classpath, then emits a `groovy_test`. The Spock jar
    version is selected by the active toolchain's Groovy major.minor —
    Groovy 2.5 pulls Spock 1.3 (JUnit 4 path), Groovy 3.0 / 4.0 pull Spock
    2.3 (JUnit 5 Platform path). The launcher invocation auto-routes
    through `org.junit.runner.JUnitCore` or
    `org.junit.platform.console.ConsoleLauncher` based on the toolchain's
    resolved `runner_class`; the macro itself stays signature-stable.

    Args:
      name: A unique name for this target.
      specs: `.groovy` files defining Spock specifications.
      deps: Libraries on both compile-time and runtime classpath.
      groovy_srcs: Additional `.groovy` helper sources compiled into a
        supporting `groovy_library`.
      java_srcs: Additional `.java` helper sources compiled into a
        supporting `java_library`.
      data: Runtime data files exposed via runfiles.
      resources: Files packaged into a side `java_library` and added to
        the test classpath.
      jvm_flags: Flags embedded into the generated test launcher script.
      size: Bazel test size. Defaults to `small`.
      tags: Bazel test tags.
      src_roots: Source-root prefixes forwarded to the underlying
        `groovy_test` for FQCN derivation. Defaults to
        `["src/test/groovy", "src/test/java"]`.
    """
    groovy_lib_deps = deps + [
        "@junit_artifact//jar",
        "@spock_artifact//jar",
    ]
    test_deps = deps + [
        "@junit_artifact//jar",
        "@spock_artifact//jar",
    ]

    if len(specs) == 0:
        fail("Must provide at least one file in specs")

    # Put all Java sources into a Java library
    if java_srcs:
        java_library(
            name = name + "-javalib",
            srcs = java_srcs,
            testonly = 1,
            deps = deps + [
                "@junit_artifact//jar",
                "@spock_artifact//jar",
            ],
        )
        groovy_lib_deps += [name + "-javalib"]
        test_deps += [name + "-javalib"]

    # Put all specs and Groovy sources into a Groovy library
    groovy_library(
        name = name + "-groovylib",
        srcs = specs + groovy_srcs,
        testonly = 1,
        deps = groovy_lib_deps,
    )
    test_deps += [name + "-groovylib"]

    # Create a groovy test
    groovy_test(
        name = name,
        deps = test_deps,
        srcs = specs,
        data = data,
        resources = resources,
        jvm_flags = jvm_flags,
        size = size,
        tags = tags,
        src_roots = src_roots,
    )

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

"""Public Groovy rules.

Chapter 4 of the v0.1.0 release narrative rewrites the rule implementations
to consume the toolchain plumbing landed in chapter 3 via the helpers in
`//groovy/private:actions.bzl`. Macro signatures (`groovy_library`,
`groovy_and_java_library`, `groovy_binary`, `groovy_test`,
`groovy_junit_test`, `spock_test`) remain unchanged so existing example
trees and downstream BUILD files keep working without edits.

Hermeticity wins absorbed here — see notes/design-hermetic.md and
decisions/ADR-005-bazel-9-baseline.md — issues 001, 002, 003, 040, 041,
042, 050, 051.
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
    """Rule analogous to java_library that accepts .groovy sources instead of
    .java sources. The result is wrapped in a java_import so that java rules
    may depend on it.
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
    """Accepts .groovy and .java srcs to create a groovy_library and a
    java_library. The groovy_library will depend on the java_library, so the
    Groovy code may reference the Java code but not vice-versa.
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
    """Rule analogous to java_binary that accepts .groovy sources instead of
    .java sources.
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
# `src_roots` generalization (ISSUE-025) is deferred to v0.2.
# ---------------------------------------------------------------------------

def path_to_class(path):
    """Convert a test source path to a Java/Groovy fully-qualified class name.

    Accepts:
      * `src/test/groovy/<pkg>/<Cls>.groovy` → `<pkg>.<Cls>`
      * `src/test/java/<pkg>/<Cls>.java`     → `<pkg>.<Cls>`
      * `src/test/java/<pkg>/<Cls>.groovy`   → `<pkg>.<Cls>`  (Groovy under java/
                                                              is legal — groovyc
                                                              accepts mixed sources)

    Fails loudly on any other layout. ISSUE-025 (v0.2) generalizes via a
    `src_roots` attr.
    """
    if path.startswith("src/test/groovy/"):
        prefix = "src/test/groovy/"
    elif path.startswith("src/test/java/"):
        prefix = "src/test/java/"
    else:
        fail("groovy_test sources must live under src/test/java or src/test/groovy, got: " + path)

    if path.endswith(".groovy"):
        ext = ".groovy"
    elif path.endswith(".java"):
        ext = ".java"
    else:
        fail("groovy_test src {} has unrecognized extension (expected .groovy or .java)".format(path))

    return path[len(prefix):path.rindex(ext)].replace("/", ".")

# ---------------------------------------------------------------------------
# groovy_test — toolchain-resolved test launcher.
# ISSUE-003: returns [DefaultInfo(runfiles=...)] instead of legacy struct.
# ---------------------------------------------------------------------------

def _groovy_test_impl(ctx):
    # Resolve the runtime classpath off the toolchain + caller-supplied deps.
    # Chapter 5 routes JUnit/Spock through `dep_providers`; until then they
    # come through the rule's own `deps` attribute (unchanged from upstream).
    classpath = test_runtime_classpath(ctx, ctx.attr.deps + ctx.attr._implicit_deps)
    classes = [path_to_class(src.path) for src in ctx.files.srcs]

    write_test_launcher(
        ctx = ctx,
        classpath = classpath,
        classes = classes,
        jvm_flags = ctx.attr.jvm_flags,
        # Hard-coded JUnit 4 runner FQCN matches the upstream behavior; the
        # `groovy.testing(junit = "5")` tag class (chapter 5 / ISSUE-047) will
        # plumb the runner class through the toolchain so JUnit 5 works.
        runner_class = "org.junit.runner.JUnitCore",
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
        tags = []):
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
        tags = []):
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
        tags = []):
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
    )

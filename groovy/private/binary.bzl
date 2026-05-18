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

"""`groovy_binary` symbolic macro — wraps `rules_java`'s `java_binary`.

The coupling is scoped and documented; re-implementing the launcher
(Linux/Windows/coverage) is a v0.2 follow-up if needed. The runtime
Groovy SDK jar is added via a hidden `groovy_sdk_runtime` target rather
than a literal `@groovy_sdk_artifact//:groovy` label so the rules' own
`.bzl` files stay free of legacy compat-repo names (ISSUE-061).

`inherit_attrs = native.java_binary` does not work under Bazel 9.1.0
because `rules_java`'s exported `java_binary` is a legacy `def`-based
wrapper and `native.java_binary`'s introspectable attr surface is
empty. The macro therefore declares the `java_binary` attrs it cares
about explicitly and forwards them through, matching the original PR-25
shape from `groovy/groovy.bzl`.
"""

load("@rules_java//java:defs.bzl", "JavaInfo", "java_binary")
load("//groovy/private:library.bzl", "groovy_library")
load("//groovy/private:runtime.bzl", "groovy_sdk_runtime")

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
    groovy_sdk_runtime(
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
classpath via a hidden `groovy_sdk_runtime` helper rule so this macro
no longer needs to reference `@groovy_sdk_artifact//:groovy` by literal
label.

Common `java_binary` attributes (`main_class`, `jvm_flags`, `data`,
`env`, `args`, `stamp`, `launcher`, `resources`, `classpath_resources`,
`deploy_manifest_lines`, `use_testrunner`) are exposed explicitly and
forwarded to the underlying `java_binary`. The `runtime_deps` attribute
is owned by this macro — the generated `groovy_sdk_runtime` target
plus, when `srcs` is non-empty, an internal `name + "_lib"`
`groovy_library` for the binary's own sources are wired through it
automatically. Internal scaffolding (the SDK-runtime and library
targets) lives at macro-scope visibility, not the binary's package
public surface.
""",
)

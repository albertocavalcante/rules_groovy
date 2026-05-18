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

"""`groovy_library` rule + `groovy_and_java_library` deprecated alias macro.

Single rule (not macro+rule). Returns `JavaInfo` directly, accepts mixed
`.groovy` + `.java` srcs, and re-exports the Groovy SDK runtime jar via
`exports` so any Java/Groovy consumer transparently sees
`groovy.lang.GroovyObject` on both compile and runtime classpath. Shape
mirrors rules_kotlin's `kt_jvm_library` (see jvm.bzl:371-410).

`groovy_and_java_library` is a Bazel-8+ symbolic-macro alias for
`groovy_library`.
"""

load("@rules_java//java:defs.bzl", "JavaInfo")
load("//groovy/private:actions.bzl", "REQUIRED_TOOLCHAINS", "compile_groovy")
load("//groovy/private:runtime.bzl", "sdk_runtime_javainfo")
load("//groovy/private:toolchain.bzl", "GroovyLibraryInfo")

def _groovy_library_impl(ctx):
    output_jar = ctx.actions.declare_file("lib" + ctx.attr.name + ".jar")
    compile_groovy(
        ctx = ctx,
        srcs = ctx.files.srcs,
        deps = ctx.attr.deps,
        output_jar = output_jar,
    )

    sdk_runtime = sdk_runtime_javainfo(ctx)
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

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

"""`groovy_runtime` rule and the private `_groovy_sdk_runtime` helper.

`groovy_runtime` exposes the active Groovy toolchain's resolved runtime jar
as a `JavaInfo`-providing target. The stable label is
`@rules_groovy//groovy:runtime` (declared in `groovy/BUILD`). Useful for
non-`groovy_*` rules (e.g. plain `java_binary`) that need Groovy on their
runtime classpath but don't otherwise have toolchain access.

`_groovy_sdk_runtime` is the same shape but private — `groovy_binary` uses
it to attach the SDK runtime jar onto the wrapped `java_binary`'s runtime
classpath without naming `@groovy_sdk_artifact//:groovy` by literal label
(ISSUE-061).

`sdk_runtime_javainfo` is the shared helper that wraps the toolchain's
runtime jar into a `JavaInfo`. `groovy_library` consumes it too so the
SDK runtime gets folded into the library's `exports` and every consumer
sees `groovy.lang.GroovyObject` on both compile and runtime classpath.
"""

load("@rules_java//java:defs.bzl", "JavaInfo")
load("//groovy/private:actions.bzl", "GROOVY_TOOLCHAIN_TYPE")

def sdk_runtime_javainfo(ctx):
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

# ---------------------------------------------------------------------------
# _groovy_sdk_runtime — internal rule that exposes the toolchain's Groovy
# SDK runtime jar as a JavaInfo-providing target. Consumed by `groovy_binary`
# (a macro that wraps `java_binary`) so the binary's runtime classpath
# carries `groovy.lang.*` without naming `@groovy_sdk_artifact//:groovy`.
# Re-implementing the launcher is a v0.2 follow-up; until then this is the
# scoped-coupling fix for ISSUE-061's last hardcoded label.
# ---------------------------------------------------------------------------

def _groovy_sdk_runtime_impl(ctx):
    java_info = sdk_runtime_javainfo(ctx)
    return [
        DefaultInfo(files = depset([ctx.toolchains[GROOVY_TOOLCHAIN_TYPE].groovy_info.runtime_jar])),
        java_info,
    ]

groovy_sdk_runtime = rule(
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
    java_info = sdk_runtime_javainfo(ctx)
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

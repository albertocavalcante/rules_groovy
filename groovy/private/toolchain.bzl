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

"""Groovy toolchain providers and rules.

Defines the toolchain shape consumed by `groovy_library`, `groovy_binary`,
`groovy_test`, and friends. Two providers and two rules:

  * `GroovyToolchainInfo` carries the resolved SDK (compiler, runtime jar,
    full SDK file set, version string).
  * `GroovyDepsInfo` names a `JavaInfo` bundle so the toolchain can point at
    test frameworks (junit, spock, hamcrest, ...) by logical name rather than
    by hard-coded attribute. Pattern lifted from `rules_scala`.
  * `groovy_toolchain` is the rule that produces `GroovyToolchainInfo` and a
    list of `GroovyDepsInfo` bundles.
  * `groovy_deps` wraps a `JavaInfo`-providing target into a `GroovyDepsInfo`
    with a logical name.

The toolchain type is declared in `groovy/BUILD` as
`@rules_groovy//groovy:toolchain_type`.

Compile / test actions read `ctx.toolchains["//groovy:toolchain_type"]` and
pull `GroovyToolchainInfo` off the `groovy_info` field; deps come off the
`deps` list and are matched by `GroovyDepsInfo.name`. This file only defines
the shape; the action wiring lives in `groovy/private/actions.bzl`.
"""

load("@rules_java//java:defs.bzl", "JavaInfo")

GroovyLibraryInfo = provider(
    doc = "Groovy-specific library metadata. Companion to `JavaInfo` on every " +
          "`groovy_library` target. Reserved for future `gazelle-groovy` and " +
          "strict-deps tooling; consumers should not depend on the field list " +
          "being stable across major versions.",
    fields = {
        "srcs": "depset[File]: the .groovy and .java sources that produced this library.",
    },
)

GroovyToolchainInfo = provider(
    doc = "Resolved Groovy SDK + runtime info for a single toolchain instance.",
    fields = {
        "groovyc": "File: the groovyc launcher executable (script or in-process driver).",
        "sdk_files": "depset[File]: full SDK contents for action inputs.",
        "runtime_jar": "File: the groovy-X.Y.Z.jar to put on the runtime classpath.",
        "version": "string: e.g. '4.0.32'. Diagnostics only - actions read SDK files, not the version string.",
        "runner_class": "string: FQCN of the test runner main class. " +
                        "`org.junit.runner.JUnitCore` for JUnit 4, " +
                        "`org.junit.platform.console.ConsoleLauncher` for JUnit 5. " +
                        "Consumed by `groovy_test`'s launcher template to pick the right invocation shape.",
    },
)

GroovyDepsInfo = provider(
    doc = "Named bundle of JavaInfo-providing deps reachable from a toolchain (dep_providers indirection).",
    fields = {
        "name": "string: logical name (e.g. 'junit_runner', 'spock', 'hamcrest').",
        "java_info": "JavaInfo: the actual dep bundle for consumers.",
    },
)

def _groovy_toolchain_impl(ctx):
    deps = []
    for t in ctx.attr.dep_providers:
        if GroovyDepsInfo not in t:
            fail("dep_providers target {} must provide GroovyDepsInfo (use groovy_deps).".format(t.label))
        deps.append(t[GroovyDepsInfo])
    return [platform_common.ToolchainInfo(
        groovy_info = GroovyToolchainInfo(
            groovyc = ctx.executable.groovyc,
            sdk_files = depset(ctx.files.sdk),
            runtime_jar = ctx.file.runtime_jar,
            version = ctx.attr.version,
            runner_class = ctx.attr.runner_class,
        ),
        deps = deps,
    )]

groovy_toolchain = rule(
    implementation = _groovy_toolchain_impl,
    attrs = {
        "groovyc": attr.label(
            executable = True,
            cfg = "exec",
            mandatory = True,
            doc = "The groovyc launcher target (script or in-process driver). Read via ctx.executable.groovyc.",
        ),
        "sdk": attr.label(
            mandatory = True,
            doc = "Filegroup containing the full Groovy SDK contents.",
        ),
        "runtime_jar": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The groovy-X.Y.Z.jar to place on the runtime classpath.",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Resolved SDK version string, e.g. '4.0.32'. Diagnostics only.",
        ),
        "runner_class": attr.string(
            default = "org.junit.runner.JUnitCore",
            doc = "FQCN of the test runner main class. " +
                  "Defaults to `org.junit.runner.JUnitCore` (JUnit 4). " +
                  "Set to `org.junit.platform.console.ConsoleLauncher` when the toolchain " +
                  "is wired for JUnit 5 (Jupiter / Spock 2.x). The module extension sets " +
                  "this automatically from the resolved `groovy.testing(junit = ...)` flavor.",
        ),
        "dep_providers": attr.label_list(
            providers = [[GroovyDepsInfo]],
            doc = "List of groovy_deps targets bound to this toolchain.",
        ),
    },
    doc = "Defines a Groovy toolchain: compiler, SDK file set, runtime jar, and named dep bundles.",
)

def _groovy_deps_impl(ctx):
    if JavaInfo not in ctx.attr.dep:
        fail("groovy_deps {} requires a JavaInfo-providing target; {} does not provide JavaInfo.".format(
            ctx.label,
            ctx.attr.dep.label,
        ))
    return [GroovyDepsInfo(
        name = ctx.attr.dep_name,
        java_info = ctx.attr.dep[JavaInfo],
    )]

groovy_deps = rule(
    implementation = _groovy_deps_impl,
    attrs = {
        "dep_name": attr.string(
            mandatory = True,
            doc = "Logical name the toolchain looks up at use time (e.g. 'junit_runner', 'spock').",
        ),
        "dep": attr.label(
            providers = [[JavaInfo]],
            mandatory = True,
            doc = "JavaInfo-providing target whose classpath backs this logical dep.",
        ),
    },
    doc = "Wraps a JavaInfo target into a GroovyDepsInfo with a logical name (dep_providers indirection).",
)

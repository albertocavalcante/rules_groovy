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
`groovy_test`, and friends. Two providers and one rule:

  * `GroovyToolchainInfo` carries the resolved SDK (compiler, runtime jar,
    full SDK file set, version string).
  * `GroovyLibraryInfo` is a forward-looking companion provider on every
    `groovy_library` target.
  * `groovy_toolchain` produces `GroovyToolchainInfo`.

The toolchain ships only the Groovy SDK. Test framework jars (JUnit,
Spock, Hamcrest, etc.) are user concerns; they ride in via `deps` on
the test rules and are typically resolved by `rules_jvm_external`'s
`maven.install` — see `examples/junit5_external/`.

The toolchain type is declared in `groovy/BUILD` as
`@rules_groovy//groovy:toolchain_type`. Compile / test actions read
`ctx.toolchains["//groovy:toolchain_type"]` and pull
`GroovyToolchainInfo` off the `groovy_info` field.
"""

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
    },
)

def _groovy_toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        groovy_info = GroovyToolchainInfo(
            groovyc = ctx.executable.groovyc,
            sdk_files = depset(ctx.files.sdk),
            runtime_jar = ctx.file.runtime_jar,
            version = ctx.attr.version,
        ),
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
    },
    doc = "Defines a Groovy toolchain: compiler, SDK file set, runtime jar, and version string.",
)

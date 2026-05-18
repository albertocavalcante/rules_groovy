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

"""Generates the `@groovy_toolchains` hub repository.

The hub repo is the single user-facing handle: regardless of how many
SDKs the user pinned (one default, or several `groovy.toolchain` /
`groovy.local_toolchain` calls), the hub's `:all` filegroup gives a
single `register_toolchains("@groovy_toolchains//:all")` line in
`MODULE.bazel`.

Per spec the hub BUILD file contains, for each registered SDK:

  * one `groovy_deps(...)` target per logical test dep (junit_runner,
    junit_api, junit_engine, hamcrest, spock) — the `dep` of which is
    where user `*_label` overrides land. The `groovy_toolchain` rule
    never learns of the override; it only sees a `groovy_deps` target
    with the right logical `dep_name`. That's the architectural payoff
    of the `dep_providers` indirection on the toolchain rule.
  * one `groovy_toolchain(...)` pointing at the SDK repo's `:groovyc`,
    `:sdk`, `:runtime_jar`.
  * one `toolchain(...)` declaration registering the above against
    `@rules_groovy//groovy:toolchain_type`.

A trailing `filegroup(name = "all", ...)` aggregates every toolchain
declaration so the user's `register_toolchains` line stays one-liner-
sized no matter how many SDKs the build pins.
"""

def _groovy_toolchains_hub_repository_impl(rctx):
    rctx.file("BUILD.bazel", rctx.attr.build_content, executable = False)
    if not hasattr(rctx, "repo_metadata"):
        return None
    return rctx.repo_metadata(reproducible = True)

groovy_toolchains_hub_repository = repository_rule(
    implementation = _groovy_toolchains_hub_repository_impl,
    attrs = {
        "build_content": attr.string(
            mandatory = True,
            doc = "Full text of the generated BUILD.bazel for the hub repo.",
        ),
    },
    doc = "Emits the @groovy_toolchains hub: groovy_toolchain + toolchain + :all filegroup.",
)

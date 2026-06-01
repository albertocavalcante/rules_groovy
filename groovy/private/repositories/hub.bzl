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
`groovy.local_toolchain` calls), the hub gives a single
`register_toolchains("@groovy_toolchains//:all")` line in
`MODULE.bazel` (`:all` is a target-pattern wildcard expanding to every
`toolchain` rule the hub emits).

Per spec the hub BUILD file contains, for each registered SDK:

  * one `config_setting` matching the SDK's version against the
    `@rules_groovy//groovy/config_settings:groovy_version` build flag.
  * one `groovy_toolchain(...)` pointing at the SDK repo's `:groovyc`,
    `:sdk`, `:runtime_jar`.
  * one `toolchain(...)` declaration registering the above against
    `@rules_groovy//groovy:toolchain_type` with `target_settings`
    keying off the version flag.

The SDK whose version equals `DEFAULT_GROOVY_VERSION` (or the first
declared SDK, if no spec matches) also gets a second `toolchain(...)`
gated on `:is_default` so the unset-flag case resolves cleanly.
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

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

"""Analysistest coverage for `groovy_toolchain` and `groovy_deps`.

Three cases:

  * `groovy_deps` + `groovy_toolchain` round-trip: a toolchain wrapping a
    `groovy_deps` target exposes `GroovyDepsInfo` with the right logical
    name and a non-empty `JavaInfo`.
  * `groovy_deps` rejects a target that does not provide `JavaInfo`
    (compile-time check via `providers = [[JavaInfo]]` on the rule attr).
  * `groovy_toolchain` rejects a `dep_providers` entry that does not
    provide `GroovyDepsInfo` (compile-time check via
    `providers = [[GroovyDepsInfo]]` on the rule attr).

Action-level tests over `compile_groovy` are a follow-up.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# ---------------------------------------------------------------------------
# Round-trip: groovy_toolchain exposes GroovyDepsInfo for a wrapped java_library.
# ---------------------------------------------------------------------------

def _toolchain_round_trip_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    # `groovy_toolchain` returns ToolchainInfo with `deps = [GroovyDepsInfo, ...]`.
    toolchain_info = target[platform_common.ToolchainInfo]
    asserts.true(
        env,
        hasattr(toolchain_info, "deps"),
        "Expected ToolchainInfo.deps on groovy_toolchain target.",
    )
    asserts.equals(env, 1, len(toolchain_info.deps), "expected exactly one dep_providers entry")

    dep = toolchain_info.deps[0]
    asserts.equals(env, "junit_runner", dep.name)
    asserts.true(
        env,
        dep.java_info != None,
        "GroovyDepsInfo.java_info must be populated.",
    )

    # GroovyToolchainInfo carries through the version and runtime_jar.
    asserts.equals(env, "4.0.32", toolchain_info.groovy_info.version)
    asserts.true(
        env,
        toolchain_info.groovy_info.runtime_jar != None,
        "GroovyToolchainInfo.runtime_jar must be populated.",
    )

    return analysistest.end(env)

toolchain_round_trip_test = analysistest.make(_toolchain_round_trip_test_impl)

# ---------------------------------------------------------------------------
# Failure: groovy_deps with a non-JavaInfo target must fail analysis.
# ---------------------------------------------------------------------------

def _groovy_deps_rejects_non_java_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "does not have mandatory providers")
    return analysistest.end(env)

groovy_deps_rejects_non_java_test = analysistest.make(
    _groovy_deps_rejects_non_java_test_impl,
    expect_failure = True,
)

# ---------------------------------------------------------------------------
# Failure: groovy_toolchain with a non-GroovyDepsInfo dep_providers entry
# must fail analysis.
# ---------------------------------------------------------------------------

def _toolchain_rejects_non_deps_provider_test_impl(ctx):
    env = analysistest.begin(ctx)
    asserts.expect_failure(env, "does not have mandatory providers")
    return analysistest.end(env)

toolchain_rejects_non_deps_provider_test = analysistest.make(
    _toolchain_rejects_non_deps_provider_test_impl,
    expect_failure = True,
)

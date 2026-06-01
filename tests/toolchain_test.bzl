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

"""Analysistest coverage for `groovy_toolchain`.

A toolchain exposes `GroovyToolchainInfo` with the wired SDK, runtime
jar, and version string. Action-level tests over `compile_groovy` are
a follow-up.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _toolchain_round_trip_test_impl(ctx):
    env = analysistest.begin(ctx)
    target = analysistest.target_under_test(env)

    toolchain_info = target[platform_common.ToolchainInfo]
    asserts.equals(env, "4.0.32", toolchain_info.groovy_info.version)
    asserts.true(
        env,
        toolchain_info.groovy_info.runtime_jar != None,
        "GroovyToolchainInfo.runtime_jar must be populated.",
    )

    return analysistest.end(env)

toolchain_round_trip_test = analysistest.make(_toolchain_round_trip_test_impl)

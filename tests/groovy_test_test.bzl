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

"""Analysis tests for `groovy_test` rule behavior."""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

def _find_launcher_action(actions):
    for action in actions:
        if action.mnemonic == "FileWrite" and "manual.OverrideSpec" in action.content:
            return action
    return None

def _test_classes_override_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    launcher_action = _find_launcher_action(actions)
    asserts.true(
        env,
        launcher_action != None,
        "Expected generated launcher to contain explicit test class; actions: {}".format(
            [a.mnemonic for a in actions],
        ),
    )
    if launcher_action != None:
        asserts.true(
            env,
            "manual.OverrideSpec" in launcher_action.content,
            "launcher must use explicit test_classes value",
        )
        asserts.false(
            env,
            "tests.HermeticityFixture" in launcher_action.content,
            "launcher must not infer from srcs when test_classes is set",
        )

    return analysistest.end(env)

test_classes_override_test = analysistest.make(_test_classes_override_test_impl)

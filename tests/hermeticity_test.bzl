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

"""Analysistest coverage for the hermeticity contract in `actions.bzl`.

The contract (see `groovy/private/actions.bzl` module docstring):

  * No `ctx.actions.run_shell` for compile actions — use `ctx.actions.run`.
  * No `use_default_shell_env = True` on any action.
  * `JAVA_HOME` is passed explicitly via `env = {"JAVA_HOME": ...}`.
  * Param files are always emitted (`use_always = True`).

The skylib `analysistest` infrastructure exposes `target.actions` via an
aspect, giving a list of `Action` objects. The `Action` type exposes
`mnemonic`, `env`, `argv`, `inputs`, `outputs`, and `content` — see
https://bazel.build/rules/lib/builtins/Action.

# NOTE: `use_default_shell_env` is not directly observable on `Action`
# from Starlark. We assert what IS observable:
#
#   * The action's `mnemonic` is `Groovyc` (or `GroovySingleJar`),
#     never something shell-shaped like `Action` or `SymlinkTree` — a
#     `ctx.actions.run_shell` call would surface as a `Action` mnemonic
#     unless the rule code overrode it (which is itself worth catching).
#   * The action's `env` dict contains `JAVA_HOME` for the `Groovyc`
#     action.
#   * The action's `env` does NOT contain entries the host environment
#     would have leaked (`PATH`, `HOME`, `USER`, `GROOVY_HOME`).
#
# A regression that flipped `use_default_shell_env = True` would not
# fail these assertions directly, but it would either drop the explicit
# `JAVA_HOME` from `env` (failing the JAVA_HOME assertion) or add host
# env keys to `env` (failing the no-host-leak assertion). The combined
# coverage is the practical proxy.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts")

# Host env keys that must not appear in any action's `env`. If any
# of these surface, hermeticity has regressed.
_HOST_ENV_KEYS = ["PATH", "HOME", "USER", "GROOVY_HOME", "LD_LIBRARY_PATH"]

def _find_action(actions, mnemonic):
    """Return the first action with the given mnemonic, or `None`."""
    for action in actions:
        if action.mnemonic == mnemonic:
            return action
    return None

def _hermeticity_test_impl(ctx):
    env = analysistest.begin(ctx)
    actions = analysistest.target_actions(env)

    mnemonics = [a.mnemonic for a in actions]

    # Compile action must be the `run`-based `Groovyc` mnemonic. A
    # `ctx.actions.run_shell` call without an explicit `mnemonic` would
    # default to `Action`; even with an explicit mnemonic, the contract
    # is that compile uses `run`, not `run_shell`.
    groovyc_action = _find_action(actions, "Groovyc")
    asserts.true(
        env,
        groovyc_action != None,
        "Expected a Groovyc action; got mnemonics: {}".format(mnemonics),
    )

    # Packaging action: singlejar via `run`.
    singlejar_action = _find_action(actions, "GroovySingleJar")
    asserts.true(
        env,
        singlejar_action != None,
        "Expected a GroovySingleJar action; got mnemonics: {}".format(mnemonics),
    )

    # JAVA_HOME is the only env key the compile action sets. The
    # toolchain resolution wires it from `java_runtime.java_home`; if
    # this assertion fails, either someone removed the explicit env
    # dict or flipped to `use_default_shell_env = True`.
    if groovyc_action != None:
        action_env = groovyc_action.env
        asserts.true(
            env,
            "JAVA_HOME" in action_env,
            "Groovyc action must set JAVA_HOME explicitly; env keys: {}".format(
                sorted(action_env.keys()),
            ),
        )
        asserts.true(
            env,
            action_env.get("JAVA_HOME", "") != "",
            "Groovyc action JAVA_HOME must be non-empty; got: {}".format(
                action_env.get("JAVA_HOME"),
            ),
        )

        # No host-env keys leaked into the action env. A
        # `use_default_shell_env = True` regression would manifest as
        # the host process's env keys being present on the action.
        for key in _HOST_ENV_KEYS:
            asserts.false(
                env,
                key in action_env,
                "Groovyc action env leaks host key `{}`; env: {}".format(
                    key,
                    sorted(action_env.keys()),
                ),
            )

    # NOTE: We deliberately do NOT assert on `singlejar_action.env`.
    # `singlejar` is a hermetic native binary from the Java toolchain
    # and does not need JAVA_HOME on its environment; the action is
    # left with an empty env dict in `actions.bzl` and that's
    # intentional.

    return analysistest.end(env)

hermeticity_test = analysistest.make(_hermeticity_test_impl)

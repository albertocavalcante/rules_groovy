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

"""Unit tests for `path_to_class` — the FQCN derivation helper used by
the `groovy_test` family (ISSUE-002 / ISSUE-025).

Covers:

  * Default `src_roots` over `.groovy` and `.java` sources, including the
    legal `.groovy` under `src/test/java/` mixed-source case.
  * A custom single root (e.g. `example/foo/src/test/groovy`).
  * Overlapping roots — longest-prefix match wins.
  * No-match — the function must `fail()` with a clear message naming
    the offending path and the configured roots. Covered via a wrapper
    rule + `analysistest(expect_failure = True)` since pure `unittest`
    cannot intercept `fail()`.
"""

load("@bazel_skylib//lib:unittest.bzl", "analysistest", "asserts", "unittest")
load("//groovy:defs.bzl", "path_to_class")

# ---------------------------------------------------------------------------
# Default `src_roots` — Maven layout at the workspace root.
# ---------------------------------------------------------------------------

_DEFAULT_ROOTS = ["src/test/groovy", "src/test/java"]

def _default_roots_test_impl(ctx):
    env = unittest.begin(ctx)

    # `.groovy` under `src/test/groovy/` — the canonical case.
    asserts.equals(
        env,
        "lib.GroovyLibTest",
        path_to_class("src/test/groovy/lib/GroovyLibTest.groovy", _DEFAULT_ROOTS),
    )

    # `.java` under `src/test/java/` — ISSUE-002's headline fix.
    asserts.equals(
        env,
        "lib.JavaLibTest",
        path_to_class("src/test/java/lib/JavaLibTest.java", _DEFAULT_ROOTS),
    )

    # `.groovy` under `src/test/java/` — legal mixed-source layout.
    asserts.equals(
        env,
        "lib.MixedSpec",
        path_to_class("src/test/java/lib/MixedSpec.groovy", _DEFAULT_ROOTS),
    )

    return unittest.end(env)

default_roots_test = unittest.make(_default_roots_test_impl)

# ---------------------------------------------------------------------------
# Custom single root — the unblocker for the examples gallery (chapter 10).
# ---------------------------------------------------------------------------

def _custom_root_test_impl(ctx):
    env = unittest.begin(ctx)

    asserts.equals(
        env,
        "pkg.Test",
        path_to_class(
            "example/foo/src/test/groovy/pkg/Test.groovy",
            ["example/foo/src/test/groovy"],
        ),
    )

    return unittest.end(env)

custom_root_test = unittest.make(_custom_root_test_impl)

# ---------------------------------------------------------------------------
# Overlapping roots — longest-prefix match wins.
# ---------------------------------------------------------------------------

def _longest_prefix_wins_test_impl(ctx):
    env = unittest.begin(ctx)

    # Roots `a` and `a/b/c` both prefix the path. Longest (`a/b/c`) wins —
    # otherwise the FQCN would carry spurious `b.c.` segments.
    asserts.equals(
        env,
        "T",
        path_to_class("a/b/c/T.groovy", ["a", "a/b/c"]),
    )

    # Order-independence: reverse the input — same result.
    asserts.equals(
        env,
        "T",
        path_to_class("a/b/c/T.groovy", ["a/b/c", "a"]),
    )

    return unittest.end(env)

longest_prefix_wins_test = unittest.make(_longest_prefix_wins_test_impl)

# ---------------------------------------------------------------------------
# No-match — must `fail()` with a clear diagnostic.
#
# `unittest` can't catch `fail()` (it aborts analysis). We wrap the call
# in a tiny rule whose analysis phase invokes `path_to_class` with a
# guaranteed no-match path, then assert via `analysistest(expect_failure)`
# that the documented error message surfaces.
# ---------------------------------------------------------------------------

def _no_match_rule_impl(ctx):
    # Forces `path_to_class` to fail: `wrong/T.groovy` does not start
    # with any of the default roots.
    path_to_class("wrong/T.groovy", _DEFAULT_ROOTS)
    return [DefaultInfo()]

no_match_rule = rule(implementation = _no_match_rule_impl)

def _no_match_failure_test_impl(ctx):
    env = analysistest.begin(ctx)

    # Error must name the offending path and the configured roots — that
    # diagnostic is the whole reason this code path `fail()`s instead of
    # silently producing garbage FQCNs.
    asserts.expect_failure(env, "wrong/T.groovy")
    asserts.expect_failure(env, "src/test/groovy")

    return analysistest.end(env)

no_match_failure_test = analysistest.make(
    _no_match_failure_test_impl,
    expect_failure = True,
)

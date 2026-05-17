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

"""Test-artifacts hub repository rule.

Generates a single repo (default name `groovy_artifacts`) that exposes the
test-framework JARs (JUnit + Spock + transitive deps) by logical name.

Each logical name resolves to one of:

  * a `java_import` wrapping the JAR fetched by a sibling http_jar repo
    (default pinned path, integrity from versions.bzl), or
  * an `alias` to a user-supplied label from the `groovy.testing(..._label =
    ...)` overrides — the user owns the JavaInfo provenance in that case.

The hub is purely a name-binding layer; URL/integrity work happens in the
per-artifact http_jar repos created by the extension. This keeps the
artifact data in versions.bzl and the wiring in extensions.bzl, with the
hub repo's only responsibility being label re-pointing — exactly what
`*_label` overrides need.
"""

_ARTIFACTS_TEMPLATE = Label("//groovy/private/repositories/templates:artifacts.BUILD.tpl")

def _groovy_artifacts_repository_impl(rctx):
    rctx.template(
        "BUILD.bazel",
        _ARTIFACTS_TEMPLATE,
        substitutions = {"{BODY}": rctx.attr.build_body},
        executable = False,
    )

    if not hasattr(rctx, "repo_metadata"):
        return None
    return rctx.repo_metadata(reproducible = True)

groovy_artifacts_repository = repository_rule(
    implementation = _groovy_artifacts_repository_impl,
    attrs = {
        "build_body": attr.string(
            mandatory = True,
            doc = "Body of the generated BUILD file (java_import / alias declarations). " +
                  "Composed at extension time from the resolved testing-tag spec.",
        ),
    },
    doc = "Emits a hub repo whose BUILD aliases JUnit / Spock artifacts by logical name.",
)

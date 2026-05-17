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

"""Repository rules that materialize a Groovy SDK into an external repo.

Two rules are exposed:

  * `groovy_sdk_repository` — downloads + extracts an Apache Groovy binary
    zip. Honors mirror-URL overrides; integrity is required for the
    extension to mark the repo reproducible.
  * `groovy_local_sdk_repository` — symlinks an already-installed SDK from
    a filesystem path. `local = True` so changes to that path invalidate
    the repo. No download, no integrity check.

Both produce the same BUILD surface: `:sdk`, `:groovyc`, `:runtime_jar`,
`:groovy`. The downstream `groovy_toolchain` rule treats the two rule
flavors as interchangeable.

The SDK is staged WITHOUT strip_prefix: //groovy/private:groovyc_wrapper.sh
resolves the launcher with the glob `external/*/groovy-*/bin/groovyc`,
which requires the `groovy-X.Y.Z/` directory to be present at the repo
root.

Per-repo reproducibility: when the user pins integrity (the registry
default path, or an explicit override), `rctx.repo_metadata(reproducible
= True)` lets the extension as a whole stay reproducible. When the user
overrides URLs without supplying integrity, that single repo degrades to
non-reproducible while the rest of the build's lockfile stays clean.
Pattern lifted from rules_python `python_repository.bzl:227-235`.
"""

_SDK_TEMPLATE = Label("//groovy/private/repositories/templates:sdk.BUILD.tpl")
_LOCAL_SDK_TEMPLATE = Label("//groovy/private/repositories/templates:local_sdk.BUILD.tpl")

def _format_version(template, version):
    """Substitute `{version}` in registry templates.

    Registry entries express URLs / strip_prefix / lib_jar with `{version}`
    placeholders so a new patch release adds one row rather than five.
    """
    return template.replace("{version}", version)

def _groovy_sdk_repository_impl(rctx):
    version = rctx.attr.version
    urls = [_format_version(u, version) for u in rctx.attr.urls]
    strip_prefix = _format_version(rctx.attr.strip_prefix, version)
    lib_jar_rel = _format_version(rctx.attr.lib_jar, version)
    integrity = rctx.attr.integrity

    if not urls:
        fail("groovy_sdk_repository '{}': urls is empty.".format(rctx.attr.name))

    # Deliberately do NOT pass strip_prefix to download_and_extract. The
    # wrapper script needs the `groovy-X.Y.Z/` directory to remain at the
    # repo root so its `external/*/groovy-*/bin/groovyc` glob resolves.
    download_kwargs = {"url": urls}
    if integrity:
        download_kwargs["integrity"] = integrity
    rctx.download_and_extract(**download_kwargs)

    # In-repo paths join the (un-stripped) SDK directory with the
    # registry-relative lib_jar.
    sdk_dir = strip_prefix if strip_prefix else "groovy-" + version
    in_repo_lib_jar = sdk_dir + "/" + lib_jar_rel

    rctx.template(
        "BUILD.bazel",
        _SDK_TEMPLATE,
        substitutions = {
            "{SDK_DIR}": sdk_dir,
            "{LIB_JAR}": in_repo_lib_jar,
            "{VERSION}": version,
        },
        executable = False,
    )

    # Bazel <8.3 lacks repo_metadata; degrade gracefully.
    if not hasattr(rctx, "repo_metadata"):
        return None

    reproducible = integrity != ""
    attrs_for_reproducibility = {
        "name": rctx.attr.name,
        "version": version,
        "urls": rctx.attr.urls,
        "integrity": integrity,
        "strip_prefix": rctx.attr.strip_prefix,
        "lib_jar": rctx.attr.lib_jar,
    }
    return rctx.repo_metadata(
        reproducible = reproducible,
        attrs_for_reproducibility = {} if reproducible else attrs_for_reproducibility,
    )

groovy_sdk_repository = repository_rule(
    implementation = _groovy_sdk_repository_impl,
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "Resolved Groovy version, e.g. '4.0.32'. Substituted into {version} in url/strip_prefix/lib_jar templates.",
        ),
        "urls": attr.string_list(
            mandatory = True,
            doc = "URL list; supports {version} substitution. Primary plus mirror fallbacks.",
        ),
        "integrity": attr.string(
            default = "",
            doc = "Subresource integrity (sha256-<base64>). Empty disables verification and marks the repo non-reproducible.",
        ),
        "strip_prefix": attr.string(
            default = "",
            doc = "Top-level directory inside the zip, e.g. 'groovy-{version}'. Used to locate lib_jar; the SDK is NOT actually stripped (see module docstring).",
        ),
        "lib_jar": attr.string(
            mandatory = True,
            doc = "Path to the runtime jar relative to strip_prefix, e.g. 'lib/groovy-{version}.jar'.",
        ),
    },
    doc = "Downloads an Apache Groovy SDK zip and emits :sdk / :groovyc / :runtime_jar / :groovy targets.",
)

def _groovy_local_sdk_repository_impl(rctx):
    name = rctx.attr.name
    sdk_path = rctx.attr.sdk_path
    version = rctx.attr.version
    lib_jar_rel = rctx.attr.lib_jar

    if not sdk_path:
        fail(("groovy.local_toolchain '{name}': sdk_path is required. Use an absolute or\n" +
              "workspace-relative path that contains the Groovy SDK; e.g. /opt/groovy/4.0.24.").format(name = name))

    # Symlink the SDK under a `groovy-<version>/` directory so the launcher
    # wrapper's `external/*/groovy-*/bin/groovyc` glob resolves the same way
    # it does for downloaded SDKs.
    sdk_dir = "groovy-" + version
    rctx.symlink(sdk_path, sdk_dir)

    in_repo_lib_jar = sdk_dir + "/" + lib_jar_rel

    # Best-effort existence check. `rctx.path()` returns a path object that
    # may not actually exist; `realpath` resolves and the `.exists` field
    # reflects reality. We check the lib_jar specifically because if it's
    # missing nothing else in the toolchain will work.
    lib_jar_check = rctx.path(in_repo_lib_jar)
    if not lib_jar_check.exists:
        fail(("groovy.local_toolchain '{name}': lib_jar '{lib_jar}' was not found under sdk_path\n" +
              "'{sdk_path}'. Verify the path layout (expected: <sdk_path>/{lib_jar_rel}).").format(
            name = name,
            lib_jar = in_repo_lib_jar,
            sdk_path = sdk_path,
            lib_jar_rel = lib_jar_rel,
        ))

    rctx.template(
        "BUILD.bazel",
        _LOCAL_SDK_TEMPLATE,
        substitutions = {
            "{SDK_DIR}": sdk_dir,
            "{LIB_JAR}": in_repo_lib_jar,
            "{VERSION}": version,
        },
        executable = False,
    )

    # Local SDKs are inherently non-reproducible across machines but the
    # extension reports `reproducible = True` at the module-extension level
    # because the *graph* is reproducible — only the contents on disk vary.
    # Bazel handles this via `local = True` invalidation.

groovy_local_sdk_repository = repository_rule(
    implementation = _groovy_local_sdk_repository_impl,
    local = True,
    attrs = {
        "sdk_path": attr.string(
            mandatory = True,
            doc = "Filesystem path to an existing Groovy SDK (absolute or workspace-relative).",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version string used for diagnostics and embedded in the SDK directory name.",
        ),
        "lib_jar": attr.string(
            mandatory = True,
            doc = "Path to the runtime jar relative to sdk_path, e.g. 'lib/groovy-4.0.24.jar'.",
        ),
    },
    doc = "Symlinks a Groovy SDK from a local filesystem path. No download, no integrity check.",
)

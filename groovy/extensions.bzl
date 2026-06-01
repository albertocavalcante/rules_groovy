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

"""Module extension exposing rules_groovy's user-facing MODULE.bazel API.

Two tag classes:

  * `groovy.toolchain(name, version, urls, integrity, strip_prefix, lib_jar)`
    — registers a downloaded SDK. All attrs except `name` and `version` are
    optional overrides; empty values fall back to the registry entry for
    `version`. Unknown versions require all four download fields and fail
    loudly otherwise.
  * `groovy.local_toolchain(name, sdk_path, version, lib_jar)` — registers
    an SDK already present on disk; no download.

When no tag is declared, an implicit `groovy.toolchain()` fires so the
minimal three-line MODULE.bazel works:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

The extension emits:
  * one `groovy_sdk_repository` / `groovy_local_sdk_repository` per
    registered toolchain (default repo name `groovy_sdk_artifact` for the
    implicit default; `<tag.name>_sdk` for explicit tags so multi-version
    builds get predictable names);
  * a `@groovy_toolchains` hub repo with `groovy_toolchain` and
    `toolchain(...)` per SDK.

Test framework jars (JUnit, Spock, etc.) are not managed by this
extension. Resolve them in your own MODULE.bazel via
`rules_jvm_external`'s `maven.install` and pass the resulting labels
through `groovy_junit5_test(deps = ...)` etc. See
`examples/junit5_external/` for the canonical wiring.

`extension_metadata(reproducible = True)` is always returned: the
*graph* the extension produces is a pure function of MODULE.bazel + the
private versions.bzl pins. URL-override-without-integrity degrades only
the affected repo (`rctx.repo_metadata(reproducible = False)` in
`sdk.bzl`) rather than the whole extension, mirroring the rules_python
pattern at `python_repository.bzl:227-235`.
"""

load(
    "//groovy/private:versions.bzl",
    "DEFAULT_GROOVY_VERSION",
    "GROOVY_VERSIONS",
)
load("//groovy/private/repositories:hub.bzl", "groovy_toolchains_hub_repository")
load("//groovy/private/repositories:sdk.bzl", "groovy_local_sdk_repository", "groovy_sdk_repository")

# ---------------------------------------------------------------------------
# Tag classes
# ---------------------------------------------------------------------------

_toolchain_tag = tag_class(
    attrs = {
        "name": attr.string(
            default = "groovy",
            doc = "Logical name; becomes the SDK repo name suffix (<name>_sdk) and the toolchain target name.",
        ),
        "version": attr.string(
            default = "",
            doc = "Groovy version, e.g. '4.0.32'. Empty falls back to DEFAULT_GROOVY_VERSION.",
        ),
        "urls": attr.string_list(
            default = [],
            doc = "Mirror URL list; supports '{version}' substitution. Empty falls back to the registry entry.",
        ),
        "integrity": attr.string(
            default = "",
            doc = "Subresource integrity (sha256-<base64>). Empty falls back to the registry entry.",
        ),
        "strip_prefix": attr.string(
            default = "",
            doc = "Top-level directory inside the zip. Empty falls back to the registry entry.",
        ),
        "lib_jar": attr.string(
            default = "",
            doc = "Path to the runtime jar inside the SDK. Empty falls back to the registry entry.",
        ),
    },
    doc = "Registers a downloaded Groovy SDK toolchain.",
)

_local_toolchain_tag = tag_class(
    attrs = {
        "name": attr.string(
            mandatory = True,
            doc = "Logical name; becomes the SDK repo name and the toolchain target name.",
        ),
        "sdk_path": attr.string(
            mandatory = True,
            doc = "Filesystem path to an existing Groovy SDK (absolute or workspace-relative).",
        ),
        "version": attr.string(
            mandatory = True,
            doc = "Version string for diagnostics and the SDK directory name.",
        ),
        "lib_jar": attr.string(
            mandatory = True,
            doc = "Path to the runtime jar relative to sdk_path, e.g. 'lib/groovy-4.0.24.jar'.",
        ),
    },
    doc = "Registers an existing Groovy SDK from a filesystem path; no download.",
)

# Synthetic name used to mark the implicit-default `groovy.toolchain` tag
# so `_resolve_toolchain` picks the legacy `groovy_sdk_artifact` repo
# name. Users cannot collide with this in practice; `_default_` is
# reserved.
_DEFAULT_TAG_MARKER = "_default_"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _resolve_toolchain(tag):
    """Resolve a `groovy.toolchain` tag against the registry.

    Returns a struct(version, urls, integrity, strip_prefix, lib_jar,
    repo_name, tag_name, local).
    """
    version = tag.version if tag.version else DEFAULT_GROOVY_VERSION

    if version in GROOVY_VERSIONS:
        base = GROOVY_VERSIONS[version]
        urls = tag.urls if tag.urls else [base.url_template]
        integrity = tag.integrity if tag.integrity else base.integrity
        strip_prefix = tag.strip_prefix if tag.strip_prefix else base.strip_prefix
        lib_jar = tag.lib_jar if tag.lib_jar else base.lib_jar
    else:
        # Unknown version: require all four download fields.
        missing = []
        if not tag.urls:
            missing.append("urls")
        if not tag.integrity:
            missing.append("integrity")
        if not tag.strip_prefix:
            missing.append("strip_prefix")
        if not tag.lib_jar:
            missing.append("lib_jar")
        if missing:
            fail(
                ("Groovy {version} not in registry. Pin all of urls, integrity, strip_prefix,\n" +
                 "lib_jar on this groovy.toolchain tag, or add the version to\n" +
                 "groovy/private/versions.bzl. Known versions: {known}.\n" +
                 "(missing on this tag: {missing})").format(
                    version = version,
                    known = sorted(GROOVY_VERSIONS.keys()),
                    missing = sorted(missing),
                ),
            )
        urls = tag.urls
        integrity = tag.integrity
        strip_prefix = tag.strip_prefix
        lib_jar = tag.lib_jar

    # Repo-name policy: the implicit-default tag (synthesized when no
    # `groovy.toolchain` was declared) keeps the legacy
    # `groovy_sdk_artifact` repo name until ISSUE-061 rewires the
    # remaining literal-label consumers off it. Explicit user tags get
    # `<tag.name>_sdk` for predictability in multi-version builds.
    repo_name = "groovy_sdk_artifact" if tag.name == _DEFAULT_TAG_MARKER else tag.name + "_sdk"

    return struct(
        version = version,
        urls = urls,
        integrity = integrity,
        strip_prefix = strip_prefix,
        lib_jar = lib_jar,
        repo_name = repo_name,
        tag_name = tag.name,
        local = False,
        sdk_path = "",
    )

def _local_spec(tag):
    """Build a spec struct for a `groovy.local_toolchain` tag.

    Local toolchains use the tag name as the repo name (no `_sdk`
    suffix) because they're always explicitly named by the user.
    """
    return struct(
        version = tag.version,
        urls = [],
        integrity = "",
        strip_prefix = "",
        lib_jar = tag.lib_jar,
        sdk_path = tag.sdk_path,
        repo_name = tag.name,
        tag_name = tag.name,
        local = True,
    )

def _emit_sdk_repo(spec):
    """Instantiate the SDK repo (downloaded or local) for a resolved spec."""
    if spec.local:
        groovy_local_sdk_repository(
            name = spec.repo_name,
            sdk_path = spec.sdk_path,
            version = spec.version,
            lib_jar = spec.lib_jar,
        )
    else:
        groovy_sdk_repository(
            name = spec.repo_name,
            version = spec.version,
            urls = spec.urls,
            integrity = spec.integrity,
            strip_prefix = spec.strip_prefix,
            lib_jar = spec.lib_jar,
        )

def _toolchain_target_name(spec):
    """Hub-repo target name for a SDK spec, e.g. 'groovy_4_0_32'."""
    return "groovy_" + spec.version.replace(".", "_").replace("-", "_")

def _version_config_setting_name(version):
    """Hub-repo config_setting name for a version, e.g. '4.0.32' -> 'is_groovy_4_0_32'."""
    return "is_groovy_" + version.replace(".", "_").replace("-", "_")

def _hub_build_content(specs, default_version):
    """Render the full BUILD content for @groovy_toolchains.

    Each registered SDK gets a per-version `config_setting`, one
    `groovy_toolchain`, and one `toolchain(...)` with `target_settings`
    keying off the version flag. The SDK whose version equals
    `default_version` (or the first declared spec if none match) also
    gets a second `toolchain(...)` gated on `:is_default` — a
    `config_setting` matching the empty-string flag value — so
    `bazel build //...` with no flag still resolves to the default
    toolchain.
    """
    lines = [
        "# Generated by //groovy:extensions.bzl. Do not edit by hand.",
        "",
        "load(\"@rules_groovy//groovy:defs.bzl\", \"groovy_toolchain\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
        ("config_setting(\n" +
         "    name = \"is_default\",\n" +
         "    flag_values = {\"@rules_groovy//groovy/config_settings:groovy_version\": \"\"},\n" +
         "    visibility = [\"//visibility:public\"],\n" +
         ")\n"),
    ]

    seen_versions = {}

    default_spec_index = -1
    for i, spec in enumerate(specs):
        if spec.version == default_version:
            default_spec_index = i
            break
    if default_spec_index == -1 and specs:
        default_spec_index = 0

    for i, spec in enumerate(specs):
        tname = _toolchain_target_name(spec)
        version_setting = _version_config_setting_name(spec.version)

        if spec.version not in seen_versions:
            seen_versions[spec.version] = True
            lines.append(
                ("config_setting(\n" +
                 "    name = \"{name}\",\n" +
                 "    flag_values = {{\"@rules_groovy//groovy/config_settings:groovy_version\": \"{version}\"}},\n" +
                 "    visibility = [\"//visibility:public\"],\n" +
                 ")\n").format(
                    name = version_setting,
                    version = spec.version,
                ),
            )

        lines.append(
            ("groovy_toolchain(\n" +
             "    name = \"{name}\",\n" +
             "    groovyc = \"@{sdk}//:groovyc\",\n" +
             "    sdk = \"@{sdk}//:sdk\",\n" +
             "    runtime_jar = \"@{sdk}//:runtime_jar\",\n" +
             "    version = \"{version}\",\n" +
             ")\n").format(
                name = tname,
                sdk = spec.repo_name,
                version = spec.version,
            ),
        )

        tc_target = tname + "_toolchain"
        lines.append(
            ("toolchain(\n" +
             "    name = \"{name}\",\n" +
             "    target_settings = [\":{setting}\"],\n" +
             "    toolchain = \":{tc}\",\n" +
             "    toolchain_type = \"@rules_groovy//groovy:toolchain_type\",\n" +
             ")\n").format(
                name = tc_target,
                setting = version_setting,
                tc = tname,
            ),
        )

        if i == default_spec_index:
            default_tc_target = tname + "_toolchain_default"
            lines.append(
                ("toolchain(\n" +
                 "    name = \"{name}\",\n" +
                 "    target_settings = [\":is_default\"],\n" +
                 "    toolchain = \":{tc}\",\n" +
                 "    toolchain_type = \"@rules_groovy//groovy:toolchain_type\",\n" +
                 ")\n").format(
                    name = default_tc_target,
                    tc = tname,
                ),
            )

    # `register_toolchains("@groovy_toolchains//:all")` uses `:all` as a
    # target-pattern wildcard that expands to every `toolchain` rule in
    # the package; no explicit `:all` filegroup needed.

    return "\n".join(lines)

def _synthetic_default_tag():
    """In-memory `groovy.toolchain` tag for the implicit default."""
    return struct(
        name = _DEFAULT_TAG_MARKER,
        version = "",
        urls = [],
        integrity = "",
        strip_prefix = "",
        lib_jar = "",
    )

# ---------------------------------------------------------------------------
# `_groovy_impl` — the extension entrypoint.
# ---------------------------------------------------------------------------

def _groovy_impl(module_ctx):
    specs = []
    saw_explicit_toolchain = False

    for mod in module_ctx.modules:
        for tag in mod.tags.toolchain:
            saw_explicit_toolchain = True
            specs.append(_resolve_toolchain(tag))
        for tag in mod.tags.local_toolchain:
            saw_explicit_toolchain = True
            specs.append(_local_spec(tag))

    if not saw_explicit_toolchain:
        specs.append(_resolve_toolchain(_synthetic_default_tag()))

    for spec in specs:
        _emit_sdk_repo(spec)

    groovy_toolchains_hub_repository(
        name = "groovy_toolchains",
        build_content = _hub_build_content(specs, DEFAULT_GROOVY_VERSION),
    )

    return module_ctx.extension_metadata(
        root_module_direct_deps = ["groovy_toolchains"],
        root_module_direct_dev_deps = [],
        reproducible = True,
    )

# ---------------------------------------------------------------------------
# Public extension declaration.
# ---------------------------------------------------------------------------

groovy = module_extension(
    implementation = _groovy_impl,
    tag_classes = {
        "toolchain": _toolchain_tag,
        "local_toolchain": _local_toolchain_tag,
    },
    doc = """Configures Groovy SDKs and registered toolchains.

Two tag classes — `toolchain`, `local_toolchain` — plus an implicit
default so the minimal MODULE.bazel is three lines:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

Test framework jars are not managed by this extension. Resolve them
via `rules_jvm_external`'s `maven.install` and pass the labels through
`groovy_junit5_test(deps = ...)` etc. See `examples/junit5_external/`.
""",
)

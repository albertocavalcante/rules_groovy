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

"""Module extension exposing rules_groovy's user-facing MODULE.bazel API.

Three tag classes:

  * `groovy.toolchain(name, version, urls, integrity, strip_prefix, lib_jar)`
    — registers a downloaded SDK. All attrs except `name` and `version` are
    optional overrides; empty values fall back to the registry entry for
    `version`. Unknown versions require all four download fields and fail
    loudly otherwise.
  * `groovy.local_toolchain(name, sdk_path, version, lib_jar)` — registers
    an SDK already present on disk; no download.
  * `groovy.testing(junit, spock, maven_repo, *_label)` — wires JUnit /
    Spock artifacts into the toolchains' `dep_providers`. Defaults pin
    JARs from versions.bzl via http_jar; `*_label` attrs accept any
    JavaInfo-providing label (the rules_jvm_external opt-in path).

When no tag is declared, an implicit `groovy.toolchain()` and an
implicit `groovy.testing()` fire so the minimal three-line MODULE.bazel
works:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

The extension emits:
  * one `groovy_sdk_repository` / `groovy_local_sdk_repository` per
    registered toolchain (default repo name `groovy_sdk_artifact` for the
    implicit default; `<tag.name>_sdk` for explicit tags so multi-version
    builds get predictable names);
  * one `http_jar` per pinned-default test artifact (legacy compat names
    `junit_artifact` / `spock_artifact` kept so the un-touched
    `groovy/groovy.bzl` macros still resolve them);
  * a `@groovy_artifacts` hub repo aliasing all test deps by logical name;
  * a `@groovy_toolchains` hub repo with `groovy_toolchain` +
    `groovy_deps` + `toolchain(...)` per SDK and a `:all` filegroup.

`extension_metadata(reproducible = True)` is always returned: the
*graph* the extension produces is a pure function of MODULE.bazel + the
private versions.bzl pins. URL-override-without-integrity degrades only
the affected repo (`rctx.repo_metadata(reproducible = False)` in
`sdk.bzl`) rather than the whole extension, mirroring the rules_python
pattern at `python_repository.bzl:227-235`.
"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_jar")
load(
    "//groovy/private:versions.bzl",
    "DEFAULT_GROOVY_VERSION",
    "GROOVY_VERSIONS",
    "JUNIT4",
    "JUNIT5",
    "SPOCK_FOR_GROOVY",
)
load("//groovy/private/repositories:artifacts.bzl", "groovy_artifacts_repository")
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

_testing_tag = tag_class(
    attrs = {
        "junit": attr.string(
            default = "4",
            values = ["4", "5", "none"],
            doc = "JUnit flavor: '4' (default), '5', or 'none' (no JUnit artifacts wired).",
        ),
        "spock": attr.bool(
            default = True,
            doc = "Whether to wire a Spock artifact matched to the resolved Groovy major.minor.",
        ),
        "maven_repo": attr.string(
            default = "https://repo1.maven.org/maven2",
            doc = "Maven repo base URL for the pinned-default fetch path. Ignored for *_label overrides.",
        ),
        "junit_label": attr.string(
            default = "",
            doc = "Override label for the JUnit runner (JUnit 4 core, or JUnit 5 console launcher). Must provide JavaInfo.",
        ),
        "junit_api_label": attr.string(
            default = "",
            doc = "Override label for the JUnit 5 jupiter-api jar. Must provide JavaInfo.",
        ),
        "junit_engine_label": attr.string(
            default = "",
            doc = "Override label for the JUnit 5 jupiter-engine jar. Must provide JavaInfo.",
        ),
        "hamcrest_label": attr.string(
            default = "",
            doc = "Override label for hamcrest-core (JUnit 4 transitive dep). Must provide JavaInfo.",
        ),
        "spock_label": attr.string(
            default = "",
            doc = "Override label for spock-core. Must provide JavaInfo.",
        ),
    },
    doc = "Configures JUnit / Spock test deps wired into each registered toolchain.",
)

# Synthetic name used to mark the implicit-default `groovy.toolchain` tag
# so `_resolve_toolchain` picks the legacy `groovy_sdk_artifact` repo
# name. Users cannot collide with this in practice; `_default_` is
# reserved.
_DEFAULT_TAG_MARKER = "_default_"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _looks_like_maven_gav(s):
    """True iff `s` smells like a Maven coordinate the user mistook for a label."""
    return (s != "" and ":" in s and not s.startswith("@") and not s.startswith("//"))

def _check_label(logical_name, value):
    """Friendly error if a user passed a Maven GAV string instead of a label."""
    if not _looks_like_maven_gav(value):
        return
    fail(
        ("groovy.testing.{logical}_label: expected a Bazel label (e.g.\n" +
         "'@maven//:org_junit_jupiter_junit_jupiter'), got '{input}'.\n\n" +
         "rules_groovy does not depend on rules_jvm_external. Resolve Maven coords in\n" +
         "your own MODULE.bazel:\n\n" +
         "    maven = use_extension(\"@rules_jvm_external//:extensions.bzl\", \"maven\")\n" +
         "    maven.install(name = \"maven\", artifacts = [\"{input}\"])\n" +
         "    use_repo(maven, \"maven\")\n\n" +
         "then pass the resulting label to groovy.testing.{logical}_label.").format(
            logical = logical_name,
            input = value,
        ),
    )

def _resolve_toolchain(tag):
    """Resolve a `groovy.toolchain` tag against the registry.

    Returns a struct(version, urls, integrity, strip_prefix, lib_jar,
    repo_name, tag_name, local). See `notes/design-hermetic.md` for the
    full algorithm.
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
    # `groovy_sdk_artifact` name for back-compat with `groovy/groovy.bzl`
    # macros that still hardcode that label. Explicit user tags get
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

def _major_minor(version):
    """Return the 'MAJOR.MINOR' portion of a version string, e.g. '4.0.32' -> '4.0'."""
    parts = version.split(".")
    if len(parts) < 2:
        return version
    return parts[0] + "." + parts[1]

def _group_path(group_id):
    """Maven group-id-path conversion (replace '.' with '/')."""
    return group_id.replace(".", "/")

def _maven_url(base, coord):
    """Build a canonical Maven URL from a `group:artifact:version` coord and a base URL."""
    parts = coord.split(":")
    if len(parts) != 3:
        fail("Internal: bad Maven coord '{}' (expected group:artifact:version)".format(coord))
    group_id, artifact_id, version = parts[0], parts[1], parts[2]
    base_clean = base
    if base_clean.endswith("/"):
        base_clean = base_clean[:-1]
    return "{base}/{group}/{artifact}/{version}/{artifact}-{version}.jar".format(
        base = base_clean,
        group = _group_path(group_id),
        artifact = artifact_id,
        version = version,
    )

def _resolve_testing(tag):
    """Resolve a `groovy.testing` tag into a struct of artifact specs."""
    if tag.maven_repo == "":
        fail("groovy.testing: maven_repo cannot be empty. Default is\nhttps://repo1.maven.org/maven2.")

    _check_label("junit", tag.junit_label)
    _check_label("junit_api", tag.junit_api_label)
    _check_label("junit_engine", tag.junit_engine_label)
    _check_label("hamcrest", tag.hamcrest_label)
    _check_label("spock", tag.spock_label)

    return struct(
        junit = tag.junit,
        spock = tag.spock,
        maven_repo = tag.maven_repo,
        labels = {
            "junit": tag.junit_label,
            "junit_api": tag.junit_api_label,
            "junit_engine": tag.junit_engine_label,
            "hamcrest": tag.hamcrest_label,
            "spock": tag.spock_label,
        },
    )

def _promote_junit_flavor_for_spock(testing, groovy_major_minor):
    """Lift `testing.junit` to `"5"` when the matched Spock release demands it.

    Spock 2.x discovers specs via the JUnit Platform engine. Running it
    under JUnitCore (the JUnit 4 runner) leaves zero specs discovered at
    runtime — the failure mode that motivates ISSUE-023's bring-forward.
    The Groovy-4 default plus `spock = True` falls into this branch
    because `SPOCK_FOR_GROOVY["4.0"].junit_flavor == "5"`.

    Returns the original `testing` struct unchanged when no promotion is
    needed (junit = "none", spock disabled, unknown Groovy major.minor,
    or Spock's matched release already runs under JUnit 4).
    """
    if testing.junit == "none":
        return testing
    if not testing.spock:
        return testing
    if groovy_major_minor not in SPOCK_FOR_GROOVY:
        return testing
    required = SPOCK_FOR_GROOVY[groovy_major_minor].junit_flavor
    if required != "5" or testing.junit == "5":
        return testing
    return struct(
        junit = "5",
        spock = testing.spock,
        maven_repo = testing.maven_repo,
        labels = testing.labels,
    )

def _default_testing_spec():
    return struct(
        junit = "4",
        spock = True,
        maven_repo = "https://repo1.maven.org/maven2",
        labels = {
            "junit": "",
            "junit_api": "",
            "junit_engine": "",
            "hamcrest": "",
            "spock": "",
        },
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

# JUnit 5 artifacts the toolchain wires onto the test classpath beyond
# the launcher itself. Order is insignificant; the runtime classpath is
# a depset and the JVM resolves by package. Each entry maps the JUNIT5
# artifact key to the logical dep_provider name we expose on the
# toolchain hub (`junit_api`, `junit_engine`, `junit_platform_launcher`,
# `junit_platform_engine`, `junit_platform_commons`, `opentest4j`,
# `apiguardian_api`). The console launcher itself lands as the legacy
# `junit_artifact` repo + the `junit_runner` logical name so the JUnit 4
# code path keeps resolving `@junit_artifact//jar:jar`.
_JUNIT5_EXTRA_ARTIFACTS = [
    ("junit-jupiter-api", "junit_api"),
    ("junit-jupiter-engine", "junit_engine"),
    ("junit-platform-launcher", "junit_platform_launcher"),
    ("junit-platform-engine", "junit_platform_engine"),
    ("junit-platform-commons", "junit_platform_commons"),
    ("opentest4j", "opentest4j"),
    ("apiguardian-api", "apiguardian_api"),
]

def _emit_artifact_http_jars(testing):
    """Instantiate per-artifact http_jar repos for the pinned-default test deps.

    Repo names follow the legacy compat shape (`junit_artifact`,
    `spock_artifact`) for JUnit 4 + Spock so the un-touched
    `groovy/groovy.bzl` macros keep resolving the labels. Other artifacts
    use `groovy_artifact_<logical>` names because no legacy consumer
    references them by literal label.

    For `junit = "5"` we fetch the full Jupiter + Platform classpath
    (jupiter-api + jupiter-engine for the test engine, platform-launcher
    + platform-engine + platform-commons for the discovery API,
    opentest4j + apiguardian-api as transitive deps). Console-launcher
    keeps the legacy `junit_artifact` repo name so consumers that import
    it by literal label (the JUnit 4 path) still resolve.

    Returns a dict {logical_name: "@<repo>//jar:jar"} for the artifacts
    that were actually fetched.
    """
    fetched = {}

    if testing.junit == "4" and testing.labels["junit"] == "":
        junit = JUNIT4.artifacts["junit"]
        http_jar(
            name = "junit_artifact",
            url = _maven_url(testing.maven_repo, junit.coord),
            integrity = junit.integrity,
        )
        fetched["junit"] = "@junit_artifact//jar:jar"

    if testing.junit == "4" and testing.labels["hamcrest"] == "":
        hc = JUNIT4.artifacts["hamcrest-core"]
        http_jar(
            name = "groovy_artifact_hamcrest",
            url = _maven_url(testing.maven_repo, hc.coord),
            integrity = hc.integrity,
        )
        fetched["hamcrest"] = "@groovy_artifact_hamcrest//jar:jar"

    if testing.junit == "5":
        if testing.labels["junit"] == "":
            console = JUNIT5.artifacts["junit-platform-console"]
            http_jar(
                name = "junit_artifact",
                url = _maven_url(testing.maven_repo, console.coord),
                integrity = console.integrity,
            )
            fetched["junit"] = "@junit_artifact//jar:jar"
        # The remaining JUnit 5 platform jars: jupiter-api / jupiter-engine
        # for the test engine, platform-launcher / platform-engine /
        # platform-commons for the discovery API, plus opentest4j and
        # apiguardian-api as transitive deps. ConsoleLauncher fails at
        # runtime without the whole set on the classpath.
        for artifact_key, logical in _JUNIT5_EXTRA_ARTIFACTS:
            # `junit_api` and `junit_engine` are the only two with a
            # public `*_label` override knob on the testing tag (added
            # before the rest of the platform jars were wired); honor
            # those overrides, fetch the rest unconditionally.
            override_attr = logical
            if testing.labels.get(override_attr, "") != "":
                continue
            spec = JUNIT5.artifacts[artifact_key]
            repo_name = "groovy_artifact_" + logical
            http_jar(
                name = repo_name,
                url = _maven_url(testing.maven_repo, spec.coord),
                integrity = spec.integrity,
            )
            fetched[logical] = "@" + repo_name + "//jar:jar"

    return fetched

def _emit_spock_jar(testing, groovy_major_minor):
    """Fetch the Spock JAR matching the resolved Groovy major.minor.

    Returns "@spock_artifact//jar:jar" if a default-path http_jar was
    created, or "" otherwise (override or `spock = False`).
    """
    if not testing.spock or testing.labels["spock"] != "":
        return ""
    if groovy_major_minor not in SPOCK_FOR_GROOVY:
        return ""
    spec = SPOCK_FOR_GROOVY[groovy_major_minor]
    http_jar(
        name = "spock_artifact",
        url = _maven_url(testing.maven_repo, spec.coord),
        integrity = spec.integrity,
    )
    return "@spock_artifact//jar:jar"

def _build_artifacts_hub_body(testing, fetched, spock_label):
    """Render the BUILD body for the @groovy_artifacts hub repo."""
    lines = []

    def _emit(logical, default_target):
        # In both branches we use `alias` rather than `java_import`: the
        # http_jar-generated `//jar:jar` target is already a java_import,
        # and Bazel rejects nested java_imports ("`jars` attribute
        # cannot contain labels of Java targets"). User overrides are
        # JavaInfo-providing labels we don't need to re-package.
        override = testing.labels.get(logical, "")
        if override != "":
            lines.append("alias(name = \"{name}\", actual = \"{actual}\")".format(
                name = logical,
                actual = override,
            ))
        elif default_target:
            lines.append("alias(name = \"{name}\", actual = \"{actual}\")".format(
                name = logical,
                actual = default_target,
            ))

    if testing.junit != "none":
        _emit("junit", fetched.get("junit"))
        if testing.junit == "4":
            _emit("hamcrest", fetched.get("hamcrest"))
        else:
            # JUnit 5: every logical from `_JUNIT5_EXTRA_ARTIFACTS` plus
            # the two with public `*_label` overrides. Each is an alias
            # into the per-artifact http_jar (or the user-supplied
            # override on the testing tag).
            for _, logical in _JUNIT5_EXTRA_ARTIFACTS:
                _emit(logical, fetched.get(logical))

    if testing.spock:
        if testing.labels["spock"] != "":
            lines.append("alias(name = \"spock\", actual = \"{}\")".format(testing.labels["spock"]))
        elif spock_label:
            lines.append("alias(name = \"spock\", actual = \"{}\")".format(spock_label))

    return "\n".join(lines) + ("\n" if lines else "")

def _logical_to_artifacts_label(logical):
    """Label inside @groovy_artifacts for a logical dep name."""
    return "@groovy_artifacts//:" + logical

def _runner_class_for(testing):
    """FQCN of the test runner main matching the resolved testing flavor.

    JUnit 4 → `org.junit.runner.JUnitCore` (positional FQCN args).
    JUnit 5 → `org.junit.platform.console.ConsoleLauncher` (`--select-class`
    per FQCN). The `groovy_test` launcher template (in actions.bzl)
    branches on the runner string to emit the right invocation shape.
    """
    if testing.junit == "5":
        return "org.junit.platform.console.ConsoleLauncher"
    return "org.junit.runner.JUnitCore"

def _hub_build_content(specs, testing, fetched, spock_label):
    """Render the full BUILD content for @groovy_toolchains."""
    lines = [
        "# Generated by //groovy:extensions.bzl. Do not edit by hand.",
        "",
        "load(\"@rules_groovy//groovy:toolchain.bzl\", \"groovy_deps\", \"groovy_toolchain\")",
        "",
        "package(default_visibility = [\"//visibility:public\"])",
        "",
    ]

    toolchain_targets = []

    # Determine which logical deps the @groovy_artifacts hub exposes for
    # this testing config; only emit groovy_deps for those. Order matters
    # only for the deterministic dep_providers list rendered into the
    # generated BUILD; the toolchain consumes them by logical name.
    available_logicals = []
    if testing.junit != "none":
        if fetched.get("junit") or testing.labels["junit"] != "":
            available_logicals.append(("junit_runner", "junit"))
        if testing.junit == "4":
            if fetched.get("hamcrest") or testing.labels["hamcrest"] != "":
                available_logicals.append(("hamcrest", "hamcrest"))
        else:
            # JUnit 5: every platform / jupiter jar fetched (or
            # overridden) becomes a `groovy_deps` on every toolchain.
            for _, logical in _JUNIT5_EXTRA_ARTIFACTS:
                if fetched.get(logical) or testing.labels.get(logical, "") != "":
                    available_logicals.append((logical, logical))
    if testing.spock and (spock_label or testing.labels["spock"] != ""):
        available_logicals.append(("spock", "spock"))

    runner_class = _runner_class_for(testing)

    for spec in specs:
        tname = _toolchain_target_name(spec)

        dep_targets = []
        for logical_name, hub_name in available_logicals:
            deps_target = "{tc}_{logical}".format(tc = tname, logical = logical_name)
            lines.append(
                ("groovy_deps(\n" +
                 "    name = \"{name}\",\n" +
                 "    dep_name = \"{logical}\",\n" +
                 "    dep = \"{actual}\",\n" +
                 ")\n").format(
                    name = deps_target,
                    logical = logical_name,
                    actual = _logical_to_artifacts_label(hub_name),
                ),
            )
            dep_targets.append(":" + deps_target)

        dep_providers_repr = "[" + ", ".join(["\"{}\"".format(t) for t in dep_targets]) + "]"
        lines.append(
            ("groovy_toolchain(\n" +
             "    name = \"{name}\",\n" +
             "    groovyc = \"@{sdk}//:groovyc\",\n" +
             "    sdk = \"@{sdk}//:sdk\",\n" +
             "    runtime_jar = \"@{sdk}//:runtime_jar\",\n" +
             "    version = \"{version}\",\n" +
             "    runner_class = \"{runner_class}\",\n" +
             "    dep_providers = {deps},\n" +
             ")\n").format(
                name = tname,
                sdk = spec.repo_name,
                version = spec.version,
                runner_class = runner_class,
                deps = dep_providers_repr,
            ),
        )

        tc_target = tname + "_toolchain"
        lines.append(
            ("toolchain(\n" +
             "    name = \"{name}\",\n" +
             "    toolchain = \":{tc}\",\n" +
             "    toolchain_type = \"@rules_groovy//groovy:toolchain_type\",\n" +
             ")\n").format(
                name = tc_target,
                tc = tname,
            ),
        )
        toolchain_targets.append(":" + tc_target)

    # No explicit `:all` filegroup: `register_toolchains("@groovy_toolchains//:all")`
    # uses `:all` as a target-pattern wildcard that expands to every
    # `toolchain` rule in the package. Defining a filegroup named `all`
    # would shadow the wildcard with an analysis-time target that does
    # not itself provide `DeclaredToolchainInfo`. The hub is purely a
    # generator of `toolchain(...)` declarations.

    return "\n".join(lines)

def _emit_mixing_diagnostic(testing, fetched):
    """Info-level print when test deps mix pinned + user-supplied labels."""
    pinned = sorted(fetched.keys())
    overridden = sorted([k for k, v in testing.labels.items() if v != ""])
    if pinned and overridden:
        # buildifier: disable=print
        print("rules_groovy: test deps {pinned: " + str(pinned) + ", overridden: " + str(overridden) + "}")

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
    testing = None
    saw_explicit_toolchain = False
    root_testing = None
    last_testing = None

    for mod in module_ctx.modules:
        for tag in mod.tags.toolchain:
            saw_explicit_toolchain = True
            specs.append(_resolve_toolchain(tag))
        for tag in mod.tags.local_toolchain:
            saw_explicit_toolchain = True
            specs.append(_local_spec(tag))
        for tag in mod.tags.testing:
            resolved = _resolve_testing(tag)
            last_testing = resolved
            if mod.is_root:
                root_testing = resolved

    # Root module's testing tag wins; otherwise the last seen tag wins.
    # This mirrors the rules_python `defaults` precedence (root module
    # has authority over children).
    testing = root_testing if root_testing != None else last_testing

    # Implicit defaults if no tags were declared.
    if not saw_explicit_toolchain:
        specs.append(_resolve_toolchain(_synthetic_default_tag()))
    if testing == None:
        testing = _default_testing_spec()

    # Materialize SDK repos.
    for spec in specs:
        _emit_sdk_repo(spec)

    # Promote the testing flavor to JUnit 5 when the matched Spock
    # release for the primary toolchain requires it. Spock 2.x discovers
    # specs via the JUnit Platform engine; running it under JUnitCore
    # builds cleanly but discovers no specs. The Groovy-4 default falls
    # into this branch (`SPOCK_FOR_GROOVY["4.0"].junit_flavor == "5"`),
    # which is the whole point of bringing ISSUE-023 forward into v0.1.0.
    primary_mm = _major_minor(specs[0].version) if specs else _major_minor(DEFAULT_GROOVY_VERSION)
    testing = _promote_junit_flavor_for_spock(testing, primary_mm)

    # Materialize per-artifact http_jar repos for the pinned-default
    # test deps. Spock fetching is gated on the *first* resolved SDK's
    # major.minor — multi-version builds get the Spock matching the
    # primary toolchain. Users with mixed Spock requirements should
    # supply `spock_label` explicitly.
    fetched = _emit_artifact_http_jars(testing)
    spock_label = _emit_spock_jar(testing, primary_mm)
    _emit_mixing_diagnostic(testing, fetched)

    # Hub repos.
    groovy_artifacts_repository(
        name = "groovy_artifacts",
        build_body = _build_artifacts_hub_body(testing, fetched, spock_label),
    )
    groovy_toolchains_hub_repository(
        name = "groovy_toolchains",
        build_content = _hub_build_content(specs, testing, fetched, spock_label),
    )

    # `root_module_direct_deps` declares which extension-emitted repos a
    # root MODULE.bazel must list under `use_repo(groovy, ...)`. Since
    # ISSUE-061's cleanup landed (test rules pull JUnit / Spock / SDK off
    # the toolchain's `dep_providers` rather than literal labels), only
    # `groovy_toolchains` is user-facing — every other repo
    # (`groovy_sdk_artifact`, `junit_artifact`, `spock_artifact`,
    # `groovy_artifacts`, `groovy_artifact_*`, `<tag>_sdk`) is internal
    # plumbing the hub references on the user's behalf.
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
        "testing": _testing_tag,
    },
    doc = """Configures Groovy SDKs, JUnit / Spock artifacts, and registered toolchains.

Three tag classes — `toolchain`, `local_toolchain`, `testing` — plus
implicit defaults so the minimal MODULE.bazel is three lines:

    groovy = use_extension("//groovy:extensions.bzl", "groovy")
    use_repo(groovy, "groovy_toolchains")
    register_toolchains("@groovy_toolchains//:all")

See `notes/design-hermetic.md` and `notes/maven-decoupling.md` for the
full API surface and override semantics.
""",
)

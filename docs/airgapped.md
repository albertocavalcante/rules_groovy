# Air-gapped, offline, and mirror-friendly builds

<!--
Copyright 2026-present Alberto Cavalcante. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

This document covers how to consume `rules_groovy` when the build machine
has restricted egress, only an internal Maven mirror, or no network at
all.

The short answer is **yes**: the Groovy SDK URL is overridable per the
recipes below, and test framework jars (JUnit, Spock, etc.) are routed
through your existing `rules_jvm_external` `maven.install` — they are
not part of `rules_groovy`'s download graph.

## 1. Inventory of every external download

| # | What | Where the URL is set | Override knobs | Integrity? |
|---|------|----------------------|----------------|------------|
| 1 | Apache Groovy SDK zip (default 4.0.32, also 3.0.25, 2.5.23) | `versions.bzl` `GROOVY_VERSIONS[*].url_template` → `groovy_sdk_repository.urls` | `groovy.toolchain(urls = [...], integrity = "...", strip_prefix = "...", lib_jar = "...")` or `groovy.local_toolchain(sdk_path = ...)` | Yes (`sha256-…` for all three pinned versions). Override `urls` without `integrity` silently degrades reproducibility. |

That is the full enumeration. No other `http_archive`, `http_file`, or
`rctx.download*` call exists in `groovy/`. The `groovyc_wrapper.sh`
performs zero network at action time.

Test framework jars (JUnit, Spock, Jupiter, Platform, etc.) come in via
`rules_jvm_external`'s `maven.install` in the consumer's `MODULE.bazel`.
Air-gapping those is `rules_jvm_external`'s domain — set
`repositories = ["https://nexus.corp/..."]` and commit a lockfile.

Out-of-scope-but-related downloads:

- The `MODULE.bazel` graph itself pulls `rules_java`, `rules_shell`,
  `bazel_skylib`, and (dev only) `stardoc` from BCR. Redirecting BCR is
  a Bazel-level concern (`--registry`, `--repository_cache`,
  `--distdir`), not a `rules_groovy` concern.
- `MODULE.bazel.lock` contains some `files.pythonhosted.org` URLs from
  stardoc's transitive pip closure. They never resolve at consumer time
  because `stardoc` is `dev_dependency = True` in this module.

## 2. Known gaps

### Gap A — SDK `urls` field is a single-element list

The registry default produces a one-element list for the Groovy SDK
download. Bazel's `download_and_extract` accepts a URL list and tries
each in order, but no built-in fallback mirror ships with the rules. A
consumer whose proxy blocks `archive.apache.org` will fail to download
even though Bazel supports multi-URL fallback natively. Override `urls`
to add corp-mirror entries.

### Gap B — SDK override without integrity silently degrades reproducibility

A user who passes `urls = ["file:///srv/mirror/..."]` without setting
`integrity` ends up with a working but non-reproducible build. The
extension uses the registry `integrity` value as fallback when the
overridden URL still points at a known version. The footgun is the
explicit-override case where the user *also* clears `integrity`.

## 3. Recipes

Three scenarios, increasing in air-gap severity.

### Scenario 1 — full internet, reproducible builds

The trivial case. Pin `rules_groovy` in `MODULE.bazel`, run
`bazel build --lockfile_mode=error //...`, and commit `MODULE.bazel.lock`.
The extension is `reproducible = True` and the per-SDK integrity hashes
make downloads byte-exact. Nothing `rules_groovy`-specific is required.

### Scenario 2 — restricted egress, internal Artifactory only

Internal Artifactory mirrors Maven Central at
`https://artifactory.corp/maven-central/` and Apache distributions at
`https://artifactory.corp/apache-archive/`.

```python
# MODULE.bazel
bazel_dep(name = "rules_groovy", version = "0.1.0")
bazel_dep(name = "rules_jvm_external", version = "7.0")

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

# Override the SDK URL to point at the corp Apache mirror.
# Integrity falls back to the registry value (no change in bytes).
groovy.toolchain(
    version = "4.0.32",
    urls = [
        "https://artifactory.corp/apache-archive/groovy/{version}/distribution/apache-groovy-binary-{version}.zip",
    ],
)
use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")

# Test framework jars via the corp Maven mirror.
maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    artifacts = [
        "org.junit.jupiter:junit-jupiter-api:5.11.0",
        "org.junit.jupiter:junit-jupiter-engine:5.11.0",
        "org.junit.platform:junit-platform-console:1.11.0",
    ],
    lock_file = "//:maven_install.json",
    repositories = ["https://artifactory.corp/maven-central"],
)
use_repo(maven, "maven")
```

Verify reproducibility with `bazel build --lockfile_mode=error //...`.

### Scenario 3 — full air-gap, pre-staged distdir + lockfile

The strongest air-gap posture: pre-stage the Groovy SDK zip under
`--distdir`, and let `rules_jvm_external`'s lockfile cover the test
deps. No build-time network access of any kind.

```python
# MODULE.bazel
bazel_dep(name = "rules_groovy", version = "0.1.0")
bazel_dep(name = "rules_jvm_external", version = "7.0")

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

# Point at a pre-staged file:// URL (--distdir resolves the SHA-keyed
# file content-wise; filename is irrelevant).
groovy.toolchain(
    version = "4.0.32",
    urls = ["file:///srv/bazel-distfiles/apache-groovy-binary-4.0.32.zip"],
)
use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    artifacts = [
        "org.junit.jupiter:junit-jupiter-api:5.11.0",
        "org.junit.jupiter:junit-jupiter-engine:5.11.0",
        "org.junit.platform:junit-platform-console:1.11.0",
    ],
    lock_file = "//:maven_install.json",
    repositories = ["https://nexus.corp/repository/maven-public"],
)
use_repo(maven, "maven")
```

Build invocation:

```sh
bazel build \
  --repository_cache=/srv/bazel-repo-cache \
  --distdir=/srv/bazel-distfiles \
  --lockfile_mode=error \
  //...
```

What populates `/srv/bazel-distfiles`: a copy of
`apache-groovy-binary-4.0.32.zip` whose SHA-256 matches the integrity in
`groovy/private/versions.bzl`. Bazel's `--distdir` is content-addressed
— filename does not matter, the SHA does.

What populates `/srv/bazel-repo-cache`: standard Bazel CAS layout,
populated on a connected machine via `bazel fetch //...` and rsynced
over.

### Scenario 4 — BYO SDK, vendored on host or NFS

Zero downloads of any kind for the SDK; combine with `rules_jvm_external`
for test deps.

```python
groovy.local_toolchain(
    name = "groovy",
    sdk_path = "/opt/groovy/4.0.32",
    version = "4.0.32",
    lib_jar = "lib/groovy-4.0.32.jar",
)
```

The repo rule is `local = True` and existence-checks `lib_jar` at fetch
time, so a misconfigured path fails fast with a clear error.

## 4. Bazel-level offline knobs

These are standard Bazel flags, not `rules_groovy`-specific, but the
overrides above are designed to compose cleanly with them.

- `--repository_cache=/path/to/cache` — content-addressed cache of
  every fetched file across builds and workspaces.
- `--distdir=/path/to/distdir` — pre-staged directory of downloaded
  files Bazel checks before hitting the network.
- `--lockfile_mode=error` — fail the build if `MODULE.bazel.lock` would
  need updating. Catches accidental network access in CI.
- `--experimental_repository_cache_hardlinks` — hardlink rather than
  copy out of the repo cache, for large SDK tarballs.

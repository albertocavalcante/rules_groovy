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
all. The downstream question this answers: "I have an internal Maven
mirror plus an internal HTTP cache. Can I use `rules_groovy` unmodified?"

The short answer is **yes** for the SDK and for the JUnit / Spock jars,
with some sharp edges around (a) Spock's transitive ASM and Groovy-JSON
deps, (b) the `maven_repo` attribute being a single string rather than a
list, and (c) several JUnit-5 platform jars that are fetched but not
individually overridable via the `*_label` route. The details below
enumerate every external download and give three concrete recipes.

## 1. Inventory of every external download

| # | What | Where the URL is set | Override knobs | Integrity? |
|---|------|----------------------|----------------|------------|
| 1 | Apache Groovy SDK zip (default 4.0.32, also 3.0.25, 2.5.23) | `versions.bzl` `GROOVY_VERSIONS[*].url_template` → `groovy_sdk_repository.urls` | `groovy.toolchain(urls = [...], integrity = "...", strip_prefix = "...", lib_jar = "...")` or `groovy.local_toolchain(sdk_path = ...)` | Yes (`sha256-…` for all three pinned versions). Override `urls` without `integrity` silently degrades reproducibility. |
| 2 | `junit:junit:4.13.2` | `http_jar(name = "junit_artifact", ...)` (JUnit 4 path) | `groovy.testing(maven_repo = "...", junit_label = "@maven//:junit_junit")` | Yes. |
| 3 | `org.hamcrest:hamcrest-core:1.3` | `http_jar(name = "groovy_artifact_hamcrest", ...)` | `maven_repo` URL or `hamcrest_label`. | Yes. |
| 4 | `org.junit.platform:junit-platform-console:1.14.4` (JUnit 5 path) | `http_jar(name = "junit_artifact", ...)` | `maven_repo` URL or `junit_label`. | Yes. |
| 5 | `org.junit.jupiter:junit-jupiter-api:5.14.4` | `http_jar(name = "groovy_artifact_junit_api", ...)` | `maven_repo` URL or `junit_api_label`. | Yes. |
| 6 | `org.junit.jupiter:junit-jupiter-engine:5.14.4` | `http_jar(name = "groovy_artifact_junit_engine", ...)` | `maven_repo` URL or `junit_engine_label`. | Yes. |
| 7 | `org.junit.platform:junit-platform-launcher:1.14.4` | `http_jar` | `maven_repo` URL only. No `*_label` override yet. | Yes. |
| 8 | `org.junit.platform:junit-platform-engine:1.14.4` | `http_jar` | `maven_repo` URL only. No `*_label` override yet. | Yes. |
| 9 | `org.junit.platform:junit-platform-commons:1.14.4` | `http_jar` | `maven_repo` URL only. No `*_label` override yet. | Yes. |
| 10 | `org.opentest4j:opentest4j:1.3.0` | `http_jar` | `maven_repo` URL only. No `*_label` override yet. | Yes. |
| 11 | `org.apiguardian:apiguardian-api:1.1.2` | `http_jar` | `maven_repo` URL only. No `*_label` override yet. | Yes. |
| 12 | `org.spockframework:spock-core:<1.3-groovy-2.5 \| 2.3-groovy-3.0 \| 2.3-groovy-4.0>` | `http_jar(name = "spock_artifact", ...)` | `maven_repo` URL, `spock_label`, or `groovy.testing(spock = False)`. | Yes (per Groovy major.minor). |

That is the full enumeration. No other `http_archive`, `http_file`, or
`rctx.download*` call exists in `groovy/`. The `groovyc_wrapper.sh`
performs zero network at action time.

Out-of-scope-but-related downloads:

- The `MODULE.bazel` graph itself pulls `rules_java`, `rules_shell`,
  `bazel_skylib`, and (dev only) `stardoc` from BCR. Redirecting BCR is
  a Bazel-level concern (`--registry`, `--repository_cache`,
  `--distdir`), not a `rules_groovy` concern.
- `MODULE.bazel.lock` contains some `files.pythonhosted.org` URLs from
  stardoc's transitive pip closure. They never resolve at consumer time
  because `stardoc` is `dev_dependency = True` in this module.

## 2. Known gaps

### Gap A — URL fields are single-element lists

The registry default produces a one-element list for the Groovy SDK
download. Bazel's `download_and_extract` accepts a URL list and tries
each in order, but no built-in fallback mirror ships with the rules. A
consumer whose proxy blocks `archive.apache.org` will fail to download
even though Bazel supports multi-URL fallback natively.

The same applies to JUnit and Spock jars: `_emit_artifact_http_jars`
calls `http_jar(url = _maven_url(testing.maven_repo, coord))` with a
single URL string rather than a list. `groovy.testing` has no plural
`urls` attribute.

### Gap B — five JUnit-5 platform jars have no `*_label` override

`groovy.testing` exposes `junit_label`, `junit_api_label`,
`junit_engine_label`, `hamcrest_label`, and `spock_label`. The full
JUnit-5 transitive set fetched by the extension is:

- `junit-platform-console` — overridable via `junit_label`
- `junit-jupiter-api` — overridable via `junit_api_label`
- `junit-jupiter-engine` — overridable via `junit_engine_label`
- `junit-platform-launcher` — no override
- `junit-platform-engine` — no override
- `junit-platform-commons` — no override
- `opentest4j` — no override
- `apiguardian-api` — no override

A user routing everything through `rules_jvm_external` can override
five jars but is forced to let `rules_groovy` fetch the remaining five
JUnit-platform jars from `maven_repo` via `http_jar`. Combined with
Gap A, even on an air-gapped setup with `rules_jvm_external` doing
proper Maven resolution against the internal mirror, `rules_groovy`
still makes five extra direct HTTP fetches against `maven_repo`.

### Gap C — `maven_repo` is a single string, not a list

A site with multiple mirrors (e.g. internal Artifactory plus Sonatype
OSS mirror plus Maven Central as last resort) cannot express that
fallback chain. `http_jar` natively supports `urls = [...]`.

### Gap D — repo override without integrity silently degrades reproducibility

A user who passes `urls = ["file:///srv/mirror/..."]` without setting
`integrity` ends up with a working but non-reproducible build. The
extension uses the registry `integrity` value as fallback when the
overridden URL still points at a known version. The footgun is the
explicit-override case where the user *also* clears `integrity`.

### Gap E — Spock's optional transitive deps are not modeled

`SPOCK_FOR_GROOVY` only pins `spock-core`. Spock 2.x at runtime also
needs:

- `org.apache.groovy:groovy-json` and `org.apache.groovy:groovy-xml`
  (Spock 2.x) — bundled inside the Apache Groovy distribution under
  `lib/`. The SDK `:sdk` filegroup picks them up, so this works in
  practice with no extra wiring.
- `net.bytebuddy:byte-buddy` — optional, only needed for `@Stub` /
  `@Spy`. Not fetched by `rules_groovy`. If a spec uses `@Spy`, you
  get a `ClassNotFoundException` at runtime and must wire byte-buddy
  via `rules_jvm_external` plus `groovy.testing(spock_label = ...)`.
- `org.objenesis:objenesis` — same situation.

A user who pre-populates a Maven mirror needs to know exactly which
coords to mirror if Spock's mocking features are in use.

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

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

# Override the SDK URL to point at the corp Apache mirror.
# Integrity falls back to the registry value (no change in bytes).
groovy.toolchain(
    version = "4.0.32",
    urls = [
        "https://artifactory.corp/apache-archive/groovy/{version}/distribution/apache-groovy-binary-{version}.zip",
    ],
)

# Redirect JUnit + Spock + every transitive JUnit-5 platform jar
# through the corp Maven mirror.
groovy.testing(
    junit = "5",
    spock = True,
    maven_repo = "https://artifactory.corp/maven-central",
)

use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

Verify reproducibility with:

```sh
bazel build --lockfile_mode=error //...
```

Caveat from Gap A: there is no automatic fallback to `repo1.maven.org`
if the corp mirror is briefly unavailable, because `maven_repo` is a
single string. If you want multi-URL fallback you must skip `maven_repo`
entirely and override every jar by label (Scenario 3 below).

### Scenario 3 — full air-gap, `rules_jvm_external` against internal Nexus

The strongest air-gap posture: route every JVM artifact through
`rules_jvm_external` (which honors `repository_cache`, integrity, and
mirrors, and is the standard Bazel-JVM offline tool), and use a
pre-staged `--distdir` directory for the Groovy SDK zip.

```python
# MODULE.bazel
bazel_dep(name = "rules_groovy", version = "0.1.0")
bazel_dep(name = "rules_jvm_external", version = "6.5")

maven = use_extension("@rules_jvm_external//:extensions.bzl", "maven")
maven.install(
    name = "maven",
    artifacts = [
        "junit:junit:4.13.2",
        "org.hamcrest:hamcrest-core:1.3",
        # JUnit 5 set:
        "org.junit.jupiter:junit-jupiter-api:5.14.4",
        "org.junit.jupiter:junit-jupiter-engine:5.14.4",
        "org.junit.platform:junit-platform-console:1.14.4",
        "org.junit.platform:junit-platform-launcher:1.14.4",
        "org.junit.platform:junit-platform-engine:1.14.4",
        "org.junit.platform:junit-platform-commons:1.14.4",
        "org.opentest4j:opentest4j:1.3.0",
        "org.apiguardian:apiguardian-api:1.1.2",
        # Spock:
        "org.spockframework:spock-core:2.3-groovy-4.0",
    ],
    repositories = [
        "https://nexus.corp/repository/maven-public",
    ],
    fetch_sources = False,
)
use_repo(maven, "maven")

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")

# Either point at a pre-staged file:// URL ...
groovy.toolchain(
    version = "4.0.32",
    urls = ["file:///srv/bazel-distfiles/apache-groovy-binary-4.0.32.zip"],
    # Integrity falls back to the registry value.
)
# ... or use the local_toolchain to skip download entirely:
# groovy.local_toolchain(
#     name = "groovy",
#     sdk_path = "/opt/groovy/4.0.32",
#     version = "4.0.32",
#     lib_jar = "lib/groovy-4.0.32.jar",
# )

groovy.testing(
    junit = "5",
    spock = True,
    # Gap B: only junit_label, junit_api_label, junit_engine_label,
    # hamcrest_label, spock_label are exposed. The other five platform
    # jars (launcher, engine, commons, opentest4j, apiguardian) are
    # fetched via http_jar regardless. To suppress those fetches the
    # user must ALSO set maven_repo to the internal Nexus:
    maven_repo = "https://nexus.corp/repository/maven-public",
    junit_label        = "@maven//:org_junit_platform_junit_platform_console",
    junit_api_label    = "@maven//:org_junit_jupiter_junit_jupiter_api",
    junit_engine_label = "@maven//:org_junit_jupiter_junit_jupiter_engine",
    spock_label        = "@maven//:org_spockframework_spock_core",
)

use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
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

Zero downloads of any kind for the SDK; combine with Scenario 3's
`rules_jvm_external` for test deps.

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

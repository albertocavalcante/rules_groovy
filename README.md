# rules_groovy

Bazel rules for building [Apache Groovy](https://www.groovy-lang.org/)
projects. Groovy libraries interoperate with Java libraries in both
directions.

This is the actively maintained fork of `bazelbuild/rules_groovy` (marked unmaintained at `9f8cd15`). The design is Bazel-9-only, bzlmod-only, hermetic by construction, and override-able by default. See [CHANGELOG.md](CHANGELOG.md) for the fork rationale.

## Setup

`rules_groovy` is not yet published to the Bazel Central Registry (BCR).
Consume it via `git_override` against a pinned commit:

```python
bazel_dep(name = "rules_groovy", version = "0.1.0")
git_override(
    module_name = "rules_groovy",
    remote = "https://github.com/albertocavalcante/rules_groovy.git",
    commit = "<pin a specific commit hash>",
)

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

Once `rules_groovy` is published to BCR, drop the `git_override` block
and pin the version in `bazel_dep` alone.

Groovy 4.0.x is the default; JUnit 5 (via the Spock-2-on-Groovy-4 auto-promotion path) and Spock 2.x are wired automatically. WORKSPACE is not supported; Bazel 9.0+ is required.

For non-`groovy_*` rules that need Groovy on their runtime classpath (e.g. a plain `java_binary` running CodeNarc or another Groovy program), depend on `@rules_groovy//groovy:runtime` — a `JavaInfo`-providing handle on the toolchain's resolved Groovy SDK jar. See [`examples/codenarc/`](examples/codenarc/).

### Pinning a Groovy version

`groovy.toolchain(version = ...)` selects the SDK. Three versions ship
in the registry: `2.5.23`, `3.0.25`, and `4.0.32` (the default). Pin a
non-default version by passing it explicitly:

```python
groovy.toolchain(version = "3.0.25")
```

Multiple `groovy.toolchain` tags can coexist in one module. The
`--@rules_groovy//groovy/config_settings:groovy_version` build flag
selects which one is used at build time. The canonical setup lives in
[`examples/multi_version/MODULE.bazel`](examples/multi_version/MODULE.bazel):

```python
groovy.toolchain(name = "groovy2", version = "2.5.23")
groovy.toolchain(name = "groovy3", version = "3.0.25")
groovy.toolchain(name = "groovy4", version = "4.0.32")
```

Build with a specific SDK:

```sh
bazel build //:lib                                                       # default 4.0.32
bazel build --@rules_groovy//groovy/config_settings:groovy_version=3.0.25 //:lib
bazel build --@rules_groovy//groovy/config_settings:groovy_version=2.5.23 //:lib
```

## What's distinctive

A short list of what this fork does that other JVM Bazel rulesets do not.

- **Bazel-9-only, bzlmod-only.** No WORKSPACE, no compat matrix tax —
  the rule set is small because it serves one ecosystem cleanly.
- **Multi-version Groovy coexistence is first-class.** Pin 2.5, 3.0,
  and 4.0 in the same build via repeated `groovy.toolchain` tags;
  pick one at build time with
  `--@rules_groovy//groovy/config_settings:groovy_version=<version>`.
  See `examples/multi_version/` for the canonical setup.
- **Zero mandatory transitive deps beyond `rules_java`.** No
  `rules_jvm_external`, no `bazel_skylib` user-visible. JUnit and
  Spock ship via pinned `http_jar` defaults.
- **Optional `rules_jvm_external` interop.** Pass any
  `JavaInfo`-providing label via `groovy.testing(*_label = ...)` to
  swap pinned test artifacts for Maven-resolved ones.
- **Hermetic actions.** No `use_default_shell_env`, no host `$PATH`,
  every download has an integrity hash, every URL is overridable.

## Quick examples

A library plus a binary that depends on it:

```python
load("@rules_groovy//groovy:defs.bzl", "groovy_library", "groovy_binary")

groovy_library(
    name = "lib",
    srcs = glob(["*.groovy"]),
)

groovy_binary(
    name = "app",
    srcs = ["App.groovy"],
    main_class = "app.App",
    deps = [":lib"],
)
```

A mixed Groovy + Java library — `groovy_library` accepts both source extensions natively via groovyc joint compilation:

```python
load("@rules_groovy//groovy:defs.bzl", "groovy_library")

groovy_library(
    name = "lib",
    srcs = glob(["*.groovy", "*.java"]),
)
```

A JUnit test (Groovy sources must live under `src/test/groovy/...` or
`src/test/java/...`):

```python
load("@rules_groovy//groovy:defs.bzl", "groovy_test")

groovy_test(
    name = "LibTest",
    srcs = ["LibTest.groovy"],
    deps = [":lib"],
)
```

A Spock specification:

```python
load("@rules_groovy//groovy:defs.bzl", "spock_test")

spock_test(
    name = "LibSpec",
    specs = ["LibSpec.groovy"],
    deps = [":lib"],
)
```

## Using rules_groovy in air-gapped or offline environments

`rules_groovy` is designed to compose with Bazel's standard offline
facilities. Every external download is integrity-pinned and every URL
is overridable from `MODULE.bazel` without forking the rules.

Two Bazel-level knobs do most of the work. `--repository_cache=/path`
points Bazel at a content-addressed cache of every fetched file, shared
across builds and workspaces. `--distdir=/path` points at a pre-staged
directory of downloaded blobs that Bazel consults before hitting the
network. Both are content-addressed by SHA-256, so a populated
`distdir` plus a populated `repository_cache` is sufficient to build
with zero network access.

For the Groovy SDK tarball itself, `groovy.toolchain` accepts a `urls`
list, an `integrity` hash, a `strip_prefix`, and a `lib_jar` path —
overriding any of these falls back to the registry default for the
fields you do not set. The typical air-gapped form points `urls` at a
`file://` path or an internal HTTP mirror:

```python
groovy.toolchain(
    version = "4.0.32",
    urls = ["https://artifactory.corp/apache-archive/groovy/4.0.32/distribution/apache-groovy-binary-4.0.32.zip"],
)
```

For the test-runtime jars (JUnit 4 / 5, Spock, Hamcrest, opentest4j,
apiguardian, and the JUnit-5 platform set), `groovy.testing(maven_repo
= ...)` swaps the Maven Central base URL for an internal mirror in a
single line:

```python
groovy.testing(
    junit = "5",
    spock = True,
    maven_repo = "https://artifactory.corp/maven-central",
)
```

For the strictest air-gap with no network at any point, the
`groovy.local_toolchain(sdk_path = ...)` path skips download entirely
and consumes a pre-installed SDK directly off the build machine.
Combined with `rules_jvm_external` for test-runtime resolution and
`--distdir` / `--repository_cache` for any remaining transitive Bazel
deps, this covers the full air-gap case.

The full enumeration of external downloads, three end-to-end
`MODULE.bazel` recipes (restricted-egress, full air-gap with internal
Nexus, BYO SDK), and the current override gaps live in
[`docs/airgapped.md`](docs/airgapped.md).

## Rule reference

`@rules_groovy//groovy:defs.bzl` is the single canonical load surface
for every public symbol — rules, providers, and helpers. The legacy
`groovy/groovy.bzl` and `groovy/toolchain.bzl` files remain as
deprecated shims that re-export from `defs.bzl`; they are slated for
removal in a future release.

Stardoc keeps the per-symbol docs in sync with the source — see
`docs/BUILD.bazel`.

- [Public rules](docs/rules-public.md) — `groovy_library`,
  `groovy_and_java_library`, `groovy_binary`, `groovy_test`,
  `groovy_junit_test`, `spock_test`.
- [Toolchain](docs/rules-toolchain.md) — `GroovyToolchainInfo`,
  `GroovyDepsInfo`, `groovy_toolchain`, `groovy_deps`.
- [Module extension](docs/rules-extension.md) — `groovy.toolchain`,
  `groovy.local_toolchain`, `groovy.testing` tag classes.

## Examples

See [`examples/`](examples/) for self-contained downstream Bazel
modules — each subdir consumes `rules_groovy` via `local_path_override`
the way a real consumer would consume it via BCR. CI runs
`bazel test //...` inside each on every PR.

- `minimal_library/` — bare `groovy_library`, no deps.
- `stdlib_only_test/` — `groovy_junit5_test` against the JDK + Groovy stdlibs.
- `junit4_test/` — `groovy_junit_test` under the legacy JUnit 4 runner (Groovy 2.5).
- `junit5_test/` — `groovy_junit5_test` under JUnit 5 Jupiter.
- `spock_test/` — `spock_test` against Spock 2.3 on the JUnit 5 Platform.
- `maven_dep/` — `rules_jvm_external` interop; pulls Guava and uses it.
- `mixed_jvm/` — `groovy_and_java_library` cross-language interop.
- `binary/` — runnable `groovy_binary`.
- `multi_version/` — three Groovy SDKs registered in the same
  module; the `groovy_version` build flag selects which one compiles
  the library.
- `codenarc/` — CodeNarc static analysis as a `bazel test //:codenarc`
  target, demonstrating `@rules_groovy//groovy:runtime` on a plain
  `java_binary`'s runtime classpath.

## Versioning and roadmap

Versions follow [semver](https://semver.org/) for normal releases. Four-component versions (e.g. `0.1.0.1`) are reserved for the rare case where a patch-set diverges from a registry pin while reusing the upstream tag.

See [CHANGELOG.md](CHANGELOG.md) for the release log.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The fork uses pull-requests-only on `main`.

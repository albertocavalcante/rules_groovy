# rules_groovy

Bazel rules for building [Apache Groovy](https://www.groovy-lang.org/)
projects. Groovy libraries interoperate with Java libraries in both
directions.

This is the actively maintained fork of `bazelbuild/rules_groovy` (marked unmaintained at `9f8cd15`). The design is Bazel-9-only, bzlmod-only, hermetic by construction, and override-able by default. See [CHANGELOG.md](CHANGELOG.md) for the fork rationale.

## Setup

Add to your `MODULE.bazel`:

```python
bazel_dep(name = "rules_groovy", version = "0.1.0")

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
use_repo(
    groovy,
    "groovy_sdk_artifact",
    "junit_artifact",
    "spock_artifact",
    "groovy_toolchains",
    "groovy_artifacts",
)
register_toolchains("@groovy_toolchains//:all")
```

Groovy 4.0.x is the default; JUnit 5 (via the Spock-2-on-Groovy-4 auto-promotion path) and Spock 2.x are wired automatically. WORKSPACE is not supported; Bazel 9.0+ is required. The `use_repo` list will collapse to just `groovy_toolchains` in a follow-up that routes JUnit/Spock through the toolchain's `dep_providers` instead of literal repo labels (ISSUE-061).

## What's distinctive

A short list of what this fork does that other JVM Bazel rulesets do not.

- **Bazel-9-only, bzlmod-only.** No WORKSPACE, no compat matrix tax —
  the rule set is small because it serves one ecosystem cleanly.
- **Multi-version Groovy coexistence is first-class.** Pin 2.5, 3.0,
  and 4.0 in the same build via repeated `groovy.toolchain` tags.
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
load("@rules_groovy//groovy:groovy.bzl", "groovy_library", "groovy_binary")

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

A mixed Groovy + Java library:

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_and_java_library")

groovy_and_java_library(
    name = "lib",
    srcs = glob(["*.groovy", "*.java"]),
)
```

A JUnit test (Groovy sources must live under `src/test/groovy/...` or
`src/test/java/...`):

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_test")

groovy_test(
    name = "LibTest",
    srcs = ["LibTest.groovy"],
    deps = [":lib"],
)
```

A Spock specification:

```python
load("@rules_groovy//groovy:groovy.bzl", "spock_test")

spock_test(
    name = "LibSpec",
    specs = ["LibSpec.groovy"],
    deps = [":lib"],
)
```

## Rule reference

Generated from the `.bzl` docstrings via Stardoc. CI keeps these in
sync with the source — see `docs/BUILD.bazel`.

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

## Versioning and roadmap

Versions follow [semver](https://semver.org/) for normal releases. Four-component versions (e.g. `0.1.0.1`) are reserved for the rare case where a patch-set diverges from a registry pin while reusing the upstream tag.

See [CHANGELOG.md](CHANGELOG.md) for the release log.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The fork uses pull-requests-only on `main`.

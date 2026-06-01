# rules_groovy

Hermetic Bazel rules for [Apache Groovy](https://www.groovy-lang.org/). Bazel-9-only, bzlmod-only, multi-version, override-able by default.

This is the actively maintained fork of `bazelbuild/rules_groovy` (marked unmaintained at upstream commit `9f8cd15`). See [CHANGELOG.md](CHANGELOG.md) for the fork rationale.

## Installation

`rules_groovy` is not yet on the Bazel Central Registry. Add to `MODULE.bazel`:

```python
bazel_dep(name = "rules_groovy", version = "0.1.0")
git_override(
    module_name = "rules_groovy",
    remote = "https://github.com/albertocavalcante/rules_groovy.git",
    commit = "93f0753ce838b3b862b017e30ce153b1e58a3366",
)

groovy = use_extension("@rules_groovy//groovy:extensions.bzl", "groovy")
use_repo(groovy, "groovy_toolchains")
register_toolchains("@groovy_toolchains//:all")
```

Groovy 4.0.32 is the default. Bazel 9.0+ required; WORKSPACE is not supported.

Test framework jars (JUnit, Spock, etc.) come from your own `rules_jvm_external` `maven.install` — see [`examples/junit5_external/`](examples/junit5_external/).

## Quickstart

```python
load("@rules_groovy//groovy:defs.bzl", "groovy_library")

groovy_library(
    name = "lib",
    srcs = glob(["*.groovy"]),
)
```

[`examples/minimal_library/`](examples/minimal_library/) is the smallest end-to-end consumer. The [Examples](#examples) table below indexes the rest.

## Pinning a Groovy version

`groovy.toolchain(version = ...)` selects the SDK. Three versions ship in the registry: `2.5.23`, `3.0.25`, and `4.0.32` (the default).

```python
groovy.toolchain(version = "3.0.25")
```

Multiple versions can coexist in one module. The
`--@rules_groovy//groovy/config_settings:groovy_version` build flag selects which one is used at build time. See [`examples/multi_version/`](examples/multi_version/) for the canonical setup.

For corporate mirrors or unregistered versions, `groovy.toolchain` accepts `urls`, `integrity`, `strip_prefix`, and `lib_jar` overrides — see [`examples/override_url/`](examples/override_url/) and [`examples/custom_version/`](examples/custom_version/).

## Hermeticity

By design: every compile and packaging action runs with an explicit environment. No host `$PATH` leak, no host `$JAVA_HOME`, no `which groovyc` fallback. The JDK comes from Bazel's standard `java_runtime_toolchain_type`; the Groovy SDK is integrity-pinned; `singlejar` packaging uses `--add_missing_directories` for `java_library` parity. Every download URL is overridable from `MODULE.bazel`.

The audited claim — explicit list of what hermeticity means here and per-action evidence for it — lives at [`docs/hermeticity.md`](docs/hermeticity.md). [`examples/reproducibility/`](examples/reproducibility/) hashes the output jar of a one-class library and asserts byte-equality across builds; [`tests/hermeticity_test.bzl`](tests/hermeticity_test.bzl) checks the `Groovyc` action's env list for host-env leaks.

## Examples

Each subdir is a self-contained Bazel module that consumes `rules_groovy` via `local_path_override`. CI runs `bazel build //... && bazel test //...` inside every one on every PR.

| Example | Demonstrates |
|---|---|
| [`minimal_library`](examples/minimal_library/) | smallest downstream consumer |
| [`junit5_external`](examples/junit5_external/) | canonical JUnit 5 wiring via `rules_jvm_external` |
| [`stdlib_only_test`](examples/stdlib_only_test/) | `groovy_junit5_test` whose source uses Groovy + JDK stdlib only |
| [`junit4_test`](examples/junit4_test/) | JUnit 4 + Groovy 2.5 |
| [`junit5_test`](examples/junit5_test/) | JUnit 5 Jupiter |
| [`spock_test`](examples/spock_test/) | Spock 2.x on the JUnit 5 Platform |
| [`maven_dep`](examples/maven_dep/) | `rules_jvm_external` interop on production deps |
| [`mixed_jvm`](examples/mixed_jvm/) | mixed `.groovy` + `.java` joint compile |
| [`binary`](examples/binary/) | runnable `groovy_binary` |
| [`multi_version`](examples/multi_version/) | per-build SDK selection via flag |
| [`override_url`](examples/override_url/) | corporate-mirror URL pattern |
| [`custom_version`](examples/custom_version/) | unregistered SDK version with full pin |
| [`codenarc`](examples/codenarc/) | CodeNarc as `bazel test`, via `@rules_groovy//groovy:runtime` |
| [`reproducibility`](examples/reproducibility/) | byte-reproducible output jars |
| [`long_classpath`](examples/long_classpath/) | param-file classpath under Linux `ARG_MAX` |
| [`local_toolchain`](examples/local_toolchain/) | BYO Groovy SDK from an on-disk path (no download) |

## Air-gapped or offline environments

Every external download is integrity-pinned and every URL is overridable. The three-pattern recipe (restricted egress / full air-gap with internal Nexus / BYO SDK via `groovy.local_toolchain`) lives in [`docs/airgapped.md`](docs/airgapped.md). [`examples/local_toolchain/`](examples/local_toolchain/) is the runnable demo of the BYO-SDK shape.

## Reference

Stardoc keeps the per-symbol docs in sync with the source.

- [Public rules](docs/rules-public.md) — `groovy_library`, `groovy_and_java_library`, `groovy_binary`, `groovy_test`, `groovy_junit_test`, `groovy_junit5_test`, `spock_test`, `groovy_runtime`
- [Toolchain](docs/rules-toolchain.md) — `GroovyToolchainInfo`, `GroovyLibraryInfo`, `groovy_toolchain`
- [Module extension](docs/rules-extension.md) — `groovy.toolchain`, `groovy.local_toolchain` tag classes

## Why this fork

A short list of what this fork does that other JVM Bazel rulesets do not.

- **Bazel-9-only, bzlmod-only.** No WORKSPACE, no compat matrix tax — the rule set is small because it serves one ecosystem cleanly.
- **Multi-version Groovy coexistence is first-class.** Pin 2.5, 3.0, and 4.0 in the same build via repeated `groovy.toolchain` tags; pick one at build time with `--@rules_groovy//groovy/config_settings:groovy_version=<version>`.
- **Pure language ruleset.** Ships only the Groovy SDK; test framework deps come from your own `rules_jvm_external` `maven.install` (matches the rules_kotlin shape). No `groovy.testing` knob, no Maven base URL strings buried in module-extension state.
- **Hermetic by construction.** See [Hermeticity](#hermeticity).

## Versioning and contributing

Versions follow [semver](https://semver.org/) for normal releases. Four-component versions (e.g. `0.1.0.1`) are reserved for the rare case where a patch-set diverges from a registry pin while reusing the upstream tag.

See [CHANGELOG.md](CHANGELOG.md) for the release log, and [CONTRIBUTING.md](CONTRIBUTING.md) for the PR-only workflow.

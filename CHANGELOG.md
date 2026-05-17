# Changelog

This is a fork of [bazelbuild/rules_groovy](https://github.com/bazelbuild/rules_groovy), started at upstream commit `9f8cd15` (marked "unmaintained" as of [PR #69](https://github.com/bazelbuild/rules_groovy/pull/69), 2020). The revival is bzlmod-only, Bazel 9.0+ only, and hermetic by construction: every URL has a pinned integrity hash, every action runs with an explicit environment, and every Groovy SDK / JUnit / Spock artifact is overridable from `MODULE.bazel` without forking the rules.

Changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [semver](https://semver.org/); four-component versions (e.g. `0.1.0.1`) are reserved for the rare case where a patch-set diverges from a registry pin while reusing the upstream tag.

## [Unreleased]

(empty)

## [0.1.0] — target

### Added

- Module extension API: `groovy.toolchain`, `groovy.local_toolchain`,
  `groovy.testing` tag classes (#11).
- Multi-version Groovy SDK coexistence; registry of pinned integrity
  hashes in `groovy/private/versions.bzl` (#8, #11).
- Optional `rules_jvm_external` interop via `groovy.testing(*_label = ...)`
  opt-in attributes (#11).
- Real Bazel toolchains: `GroovyToolchainInfo`, `GroovyDepsInfo`,
  `groovy_toolchain`, `groovy_deps` (#9).
- Hermetic compile and test-launcher actions; param files always;
  `singlejar` packaging with directory entries (#10).
- Stardoc-generated rule documentation under `docs/` with a CI
  regen-check (#14).

### Changed

- Default Groovy bumped from 2.5.8 to 4.0.32 (#12). Pin 2.5.x or 3.0.x
  explicitly via `groovy.toolchain(version = "2.5.23")` or similar.
- Bazel 9.x is the supported baseline; Bazel 7/8 cells are advisory
  only (#7).
- `rules_java` pinned to 9.6.1 (#7).
- All public rules now declare
  `toolchains = ["//groovy:toolchain_type", JDK runtime, Java
  toolchain]` (#9, #10).

### Removed

- `WORKSPACE`, `groovy/repositories.bzl`, `groovy/toolchains.bzl` (#13).
- `native.bind()` calls (#13).
- `cfg = "host"` on all attributes (#10).
- `@bazel_tools//tools/zip:zipper` references in favor of `singlejar`
  from `rules_java` (#10).
- Direct `@bazel_tools//tools/jdk:current_java_runtime` references in
  favor of toolchain resolution (#10).

### Fixed

- `path_to_class` now slices on the source's actual extension instead
  of always assuming `.groovy`, so `groovy_junit_test` with `.java`
  helper sources works (#10).
- Replaced legacy `struct(runfiles = ...)` rule return with
  `DefaultInfo(runfiles = ...)` (#10).
- Directory entries are now emitted in output jars, fixing
  [upstream #52](https://github.com/bazelbuild/rules_groovy/issues/52)
  and [#61](https://github.com/bazelbuild/rules_groovy/issues/61)
  (#10).
- Long-classpath builds work via param files, fixing
  [upstream #64](https://github.com/bazelbuild/rules_groovy/issues/64)
  (#10).

### Compatibility

- Bazel minimum: 9.0.
- Bzlmod only — `WORKSPACE` is no longer supported.
- The fork preserves macro signatures (`groovy_library`, `groovy_binary`,
  `groovy_test`, `groovy_and_java_library`, `groovy_junit_test`,
  `spock_test`) for source-level compatibility with upstream
  `bazelbuild/rules_groovy 0.0.6` BUILD files.

[Unreleased]: https://github.com/albertocavalcante/rules_groovy/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/albertocavalcante/rules_groovy/releases/tag/v0.1.0

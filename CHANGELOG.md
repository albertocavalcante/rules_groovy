# Changelog

This is a fork of [bazelbuild/rules_groovy](https://github.com/bazelbuild/rules_groovy), started at upstream commit `9f8cd15` (marked "unmaintained" as of [PR #69](https://github.com/bazelbuild/rules_groovy/pull/69), 2020). The revival is bzlmod-only, Bazel 9.0+ only, and hermetic by construction: every URL has a pinned integrity hash, every action runs with an explicit environment, and every Groovy SDK / JUnit / Spock artifact is overridable from `MODULE.bazel` without forking the rules.

Changes follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions follow [semver](https://semver.org/); four-component versions (e.g. `0.1.0.1`) are reserved for the rare case where a patch-set diverges from a registry pin while reusing the upstream tag.

## [0.1.0] — 2026-06-01

### Architecture — pure language ruleset (BREAKING)

The v0.1 surface is honest: `rules_groovy` ships only the Groovy SDK
and the build rules that consume it. Maven resolution, test framework
selection, and transitive lockfiling are user concerns, resolved by
`rules_jvm_external`'s `maven.install`. The shape matches `rules_kotlin`
/ `contrib_rules_jvm`.

Three sequenced PRs landed the architecture:

- **#40 (δ1)** — `runner_class` becomes an attr on the test rule; the
  convenience macros hardcode the FQCN per framework
  (`groovy_junit_test` → `JUnitCore`; `groovy_junit5_test` and
  `spock_test` → `ConsoleLauncher`). Behavior preserved via a toolchain
  fallback during transition.
- **#41 (δ2)** — `examples/junit5_external/` shows the destination
  pattern in tree: `rules_jvm_external` `maven.install` resolves
  Jupiter API + Engine + Platform Console, labels pass through `deps`.
- **#42 (δ3, breaking)** — the rip. Deleted: `groovy.testing` tag
  class; `GroovyDepsInfo` provider; `groovy_deps` rule; `dep_providers`
  and `runner_class` attrs on `groovy_toolchain`; `@groovy_artifacts`
  hub repo and its BUILD template; `JUNIT4` / `JUNIT5` /
  `SPOCK_FOR_GROOVY` constants in `versions.bzl`;
  `_toolchain_dep_provider_jars` / `toolchain_deps_by_name` helpers;
  `examples/testing_maven_repo/`. `runner_class` is mandatory on
  `_groovy_test` / `groovy_test`. `compile_groovy` +
  `test_runtime_classpath` stop folding toolchain framework jars onto
  their respective classpaths — everything comes from `deps`.

Examples migrated to `maven.install` with committed
`maven_install.json` lockfiles (strictly more hermetic than the prior
Starlark-pinned `http_jar` set): `junit4_test`, `junit5_test`,
`mixed_jvm`, `stdlib_only_test`, `multi_version`, `spock_test`,
`maven_dep`.

Migration for downstream consumers: drop `groovy.testing(...)` from
`MODULE.bazel`; add `bazel_dep(name = "rules_jvm_external", ...)` +
`maven.install(artifacts = [...])`; pass `@maven//:...` labels through
`groovy_junit5_test(deps = ...)` / `spock_test(deps = ...)`. See
`examples/junit5_external/` for the minimal shape.

### Documentation

- README rewritten for the git_override-consumer path. Installation
  block pins a real commit SHA (replacing the
  `"<pin a specific commit hash>"` placeholder), the
  hermetic-by-construction claim moves up into a dedicated section,
  and the Examples table indexes every `examples/` subdir with a
  one-line description. Net trim ~55% (237 → 105 lines) while
  preserving the substantive content: deeper material (fork
  rationale, air-gap recipes, full rule reference) lives under
  later headers + sibling docs.

### Added

- `docs/hermeticity.md` — the audited claim. Explicit list of what
  hermeticity means in `rules_groovy`, per-action evidence
  (compile / package / launcher / test runner / SDK repo rules),
  what hermeticity does NOT cover, and the gaps queued as v0.2
  follow-ups (sandbox-mode robustness, PATH-stripped action env,
  deploy-jar manifest determinism). README's `## Hermeticity`
  section links to it.

- `examples/junit5_external/` — canonical JUnit 5 wiring via
  `rules_jvm_external` `maven.install` + explicit `@maven//:...`
  labels in `deps`. The destination pattern after the δ3 rip. (#41)

- `examples/local_toolchain/` — the runnable demo of
  `groovy.local_toolchain`, the BYO-Groovy-SDK path. Pinned to
  Groovy 4.0.32 at `/opt/groovy-4.0.32` in CI (the workflow
  pre-installs the SDK there before the cell runs). Closes the
  ISSUE-045 acceptance gap: tag class, `_local_spec` helper, and
  `_groovy_local_sdk_repository_impl` were all in place; the
  example proves end-to-end resolution + lib_jar existence check +
  symlink layout match.

- Two downstream-consumer demos that close the acceptance gap on
  ISSUE-044 (`groovy.toolchain` override surface):
    * `examples/override_url/` — registry-known version with a
      caller-supplied `urls` list, demonstrating the corporate-mirror
      pattern. `integrity`, `strip_prefix`, `lib_jar` backfill from the
      registry.
    * `examples/custom_version/` — Groovy 4.0.24 (not in the registry)
      with all four download fields supplied. Validates the unknown-
      version error path operationally; the README captures the exact
      failure message you get when any of the four fields is missing.
  Both wired into the `examples / *` CI matrix.

### Removed

- `groovy/groovy.bzl` and `groovy/toolchain.bzl`, the deprecated
  back-compat shims that re-exported public macros / providers from
  `defs.bzl`. PR #26 marked them "slated for removal in a future
  release"; verification on 2026-05-31 found zero `load(...)` callers
  anywhere in the live tree (`groovy/`, `tests/`, `docs/`, `examples/`,
  `MODULE.bazel`, or the extension-generated hub repo). Pre-1.0 the
  removal carries no compatibility cost, and ADR-001 prefers an honest
  deletion over a permanent re-export. Downstream code that still
  loads from the legacy paths must switch to
  `load("@rules_groovy//groovy:defs.bzl", ...)`. The associated
  `groovy_bzl` and `toolchain_bzl` `bzl_library` targets are removed
  from `groovy/BUILD` as well. (ISSUE-077)

### Fixed

- `examples/multi_version/`: the example no longer fails CI when
  the toolchain's bundled Spock 1.3-groovy-2.5 is loaded onto every
  compile classpath and then crashes against a flag-selected Groovy
  3.0.x / 4.0.x toolchain
  (`IncompatibleGroovyVersionException`). The example now opts out
  of the toolchain's Spock wiring (`groovy.testing(junit = "4",
  spock = False)`) and adds a `groovy_junit_test` so the per-version
  selection is verified at runtime, not just at analysis. CI runs
  the test under the default 4.0.32 toolchain plus the explicit
  3.0.25 and 2.5.23 selections. The underlying architectural
  cleanup (drop the `groovy.testing` tag class, let users supply
  test framework deps via `rules_jvm_external`) is queued for v0.2
  per `rules_groovy-plan/notes/roadmap-v0.1-v0.2.md`. (#29, ISSUE-071)

### Changed

- License headers: bumped the fork's copyright year from
  `2025-present` to `2026-present` across all 24 first-party
  files (`.bzl`, `BUILD`, `BUILD.bazel`, `*.sh`, `*.groovy`,
  `LICENSE.txt`, `docs/airgapped.md`). The fork was started in
  early 2026; the original `2025-present` was carried over from
  upstream `bazelbuild/rules_groovy` without correction. The
  Google copyright line in `LICENSE.txt` is untouched.
  (ISSUE-060)

### CI

- Bazel remote cache wired into CI (ISSUE-080). Every workflow
  `bazel build`/`bazel test` now goes through a composite GH
  action at `.github/actions/bazel-cmd/` that selects read-write
  for same-repo PRs / `push:main` / cron / `workflow_dispatch`,
  read-only for fork PRs, and disk-only fallback when either of
  the `BAZEL_CACHE_URL` / `BAZEL_CACHE_TOKEN` secrets is unset.
  The cache URL and bearer token live only in repository secrets
  and the composite masks the URL from log output so Bazel error
  surfaces do not echo it. `.bazelrc` carries no cache flags;
  local use is documented by example in the rc comment block.

- PR triggers gain `paths-ignore: ['**/*.md']` and a per-job
  `if: !github.event.pull_request.draft` (ISSUE-080). Pure-prose
  PRs do not start the workflow; draft PRs run no jobs until they
  flip to ready-for-review (covered by the `ready_for_review` event
  type added to `on.pull_request.types`). Mixed code + docs PRs
  (the copyright-bump pattern from #30) still trigger normally
  because they touch non-`.md` files.

- Bazel 9 prebuilt `protoc` enabled (ISSUE-079). Adds
  `--@protobuf//bazel/toolchains:prefer_prebuilt_protoc=true` to the
  unconditional `build` section of `.bazelrc`. Available under
  protobuf 33.4 (already in `MODULE.bazel.lock`); skips the C++
  compile of `protoc` that Stardoc + `rules_java` would otherwise
  trigger on cold CI cells. `MODULE.bazel` gains a direct
  `bazel_dep(name = "protobuf", version = "33.4")` so the
  `@protobuf` short name resolves from the root `.bazelrc` — the
  same protobuf version is already pulled transitively through
  `rules_java`, so the line does not change the locked module
  graph. Flag location is `bazel/toolchains` in protobuf 33.4;
  later protobuf releases move it to `bazel/flags` with an alias,
  so the `bazel/toolchains` path keeps working. Protobuf v34 will
  flip the default to `true` and the explicit line can be removed
  then. The flag is intentionally NOT added to the per-example
  `.bazelrc`s — each `examples/<name>/MODULE.bazel` does not
  declare a direct dependency on `protobuf` (it's a downstream
  consumer demo), so `@protobuf` is not visible from those modules.
  Examples will still hit a cold protoc compile on the first
  example per CI runner, then warm-cache subsequent examples via
  the disk cache from ISSUE-078.

- `.bazelrc` refactored into `--config=`-layered sections
  (ISSUE-079). The unconditional defaults remain at the top (bzlmod
  + `--java_runtime_version=remotejdk_11` + the new prebuilt-protoc
  flag). Two new configs:
    * `--config=ci` — CI cell defaults: `--announce_rc`,
      `--color=yes`, `--terminal_columns=120`,
      `--lockfile_mode=error`, and `test:ci --test_output=errors`.
    * `--config=disk-cache` — pins `--disk_cache=~/.cache/bazel-disk`,
      pairing with the `actions/cache@v4` step from ISSUE-078.
  Every workflow `bazel build` / `bazel test` switches from inline
  flags (`--config=bzlmod --lockfile_mode=error --disk_cache=...`)
  to `--config=ci --config=disk-cache`. The `:bzlmod` no-op alias
  is retained for legacy callers. Remote-cache wiring lands
  separately in ISSUE-080 via the CI composite action; nothing
  about the cache is committed to `.bazelrc`.

- Workflow trimmed for budget reality (ISSUE-078). May 2026 metered
  usage showed `rules_groovy` consumed $37.62 gross of GitHub Actions
  minutes — 54% of the account total and enough to drain the 2,000-min
  free pool and trip the account-level spending cap, which stopped
  Actions across all of `albertocavalcante` until reset. Three
  structural changes:
    * macOS Bazel 9.x cell moved from per-PR to weekly cron (Mondays
      03:17 UTC) plus manual `workflow_dispatch`. macOS minutes are
      10x linux on GitHub Actions; per-PR macOS was ~67% of the entire
      workflow cost for marginal extra signal. Darwin-only regressions
      now surface within 7 days, which is well inside any downstream
      consumer feedback loop. Pre-release confidence is restored by
      firing `workflow_dispatch` before tagging — see CONTRIBUTING.md.
    * Bazel 7.x / 8.x advisory cells (4 entries) moved to a separate
      `build-advisory` job gated on `workflow_dispatch` with an
      explicit `run_advisory=true` input. ADR-005 keeps Bazel 9 as
      the only supported target, and the advisory cells were red on
      PR #31 anyway — keeping them per-PR cost ~$11/month for zero
      acted-on signal. They remain available for pre-release smoke.
    * All linux jobs (`build-linux`, `examples`, `docs-regen-check`)
      gain a Bazel disk cache via `actions/cache@v4`, keyed on
      `MODULE.bazel.lock` (or each example's own `MODULE.bazel` for
      the examples matrix). Cold-start drops from ~30-60s to ~5s on
      cache hit; SDK and Maven artifact downloads are skipped. Pass
      `--disk_cache=$HOME/.cache/bazel-disk` to `bazel build`/`test`.
  Projected reduction: ~$37/month gross -> ~$5/month gross (~85%).
  The required-cell list shrinks to `build-linux`, `examples`,
  `buildifier`, and `docs regen check` — the macOS cell and the four
  advisory cells no longer appear on PRs and so do not gate merges.

- New `buildifier` job in `.github/workflows/ci.yml`. Runs
  `buildifier --mode=check --lint=warn` over `groovy/`, `tests/`,
  `docs/`, `MODULE.bazel`, and `REPO.bazel` on every PR. Pinned to
  `bazelbuild/buildtools` v8.5.1 by SHA256. Fails on any required
  reformat or surfaced lint warning. `examples/` is intentionally
  excluded — each example is its own downstream module with its
  own style. Existing violations (three reformat-only diffs in
  `docs/BUILD.bazel`, `groovy/extensions.bzl`,
  `groovy/private/actions.bzl`; missing-docstring-args/return
  warnings on `toolchain_deps_by_name`, `test_runtime_classpath`,
  `path_to_class`; missing module-docstring on `REPO.bazel`; and
  one `unused-variable` on the `_no_match_rule_impl(ctx)` analysis
  helper — opted out with `# buildifier: disable=unused-variable`
  because `ctx` is required by Bazel's `rule(implementation=...)`
  signature) were fixed in the same PR. (ISSUE-069)

### Tests

- `tests/hermeticity_test.bzl`: analysistest that introspects the
  actions emitted by a `groovy_library`. Asserts `Groovyc` and
  `GroovySingleJar` mnemonics are present (i.e. compile + package go
  through `ctx.actions.run`, not `run_shell`); asserts the `Groovyc`
  action's `env` contains a non-empty `JAVA_HOME` and no host-env
  keys (`PATH`, `HOME`, `USER`, `GROOVY_HOME`, `LD_LIBRARY_PATH`) —
  the practical proxy for the otherwise-not-introspectable
  `use_default_shell_env` flag. (#28)
- `examples/reproducibility/`: builds a one-class `groovy_library`,
  hashes the output jar via `shasum -a 256`, and diffs against a
  checked-in golden via `bazel-skylib`'s `diff_test`. Verifies the
  `Groovyc` → `GroovySingleJar` chain is byte-reproducible across
  cold and warm builds; the golden was seeded on macOS / arm64 and
  the README documents the OS-specific drift escape hatch. (#28)
- `examples/long_classpath/`: 100 generated `groovy_library` targets
  and one consumer listing every one in `deps`. Exercises the
  param-file path from ISSUE-050: without
  `use_param_file("@%s", use_always = True)` the compile command
  line would exceed Linux's `ARG_MAX` and fail with E2BIG. Source
  files are emitted by `write_file` at analysis time so the example
  doesn't ship 100 trivial `.groovy` files. (#28)

### Added

- `@rules_groovy//groovy:runtime` target exposing the toolchain's
  resolved Groovy SDK runtime jar as a `JavaInfo`-providing target.
  Useful for plain `java_binary` and other non-`groovy_*` rules that
  need Groovy on their runtime classpath. Resolves via the
  `groovy_version` build flag introduced in #22, so the jar always
  matches the toolchain every other rule in this set is using. (#23,
  ISSUE-065)
- `examples/codenarc/`: CodeNarc as a `bazel test //:codenarc` target
  via `sh_test` + `java_binary`, consuming
  `@rules_groovy//groovy:runtime`. Pattern for static-analysis
  integration on Groovy sources without rules_groovy having to ship a
  CodeNarc-specific rule (a rules_lint upstream contribution is
  tracked separately as ISSUE-066). (#23)
- `GroovyLibraryInfo` provider, returned alongside `JavaInfo` by every
  `groovy_library` target. Carries the source-file `depset` for future
  `gazelle-groovy` and strict-deps tooling. Field list is intentionally
  small; not yet covered by SemVer until v0.2.0. (#21)
- Per-version Groovy toolchain selection via a new build flag at
  `@rules_groovy//groovy/config_settings:groovy_version` (a
  `bazel_skylib` `string_flag`, default `""`). The `@groovy_toolchains`
  hub repo now emits one `config_setting` per registered SDK plus an
  `:is_default` setting matching the unset flag value, and every
  `toolchain(...)` declaration carries a matching `target_settings`
  list. The "default" SDK (the spec whose `version` equals
  `DEFAULT_GROOVY_VERSION` if registered, else the first declared
  spec) registers a second time gated on `:is_default` so the no-flag
  case resolves to it. Closes ISSUE-064. (#22)
- `examples/multi_version/`: three `groovy.toolchain` tags
  (`2.5.23`, `3.0.25`, `4.0.32`) registered in one module; the
  README walks through the three `bazel build` invocations the new
  flag enables. The example was deferred from PR #20 pending the
  toolchain-selection mechanism this PR introduces. (#22)
- `examples/` directory: self-contained Bazel modules exercising the
  ruleset as a downstream consumer. Each subdir's `MODULE.bazel`
  pulls in `rules_groovy` via `local_path_override` and is built /
  tested in isolation by the new `examples` CI matrix. The set ships
  eight examples: `minimal_library`, `stdlib_only_test`,
  `junit4_test`, `junit5_test`, `spock_test`, `maven_dep`,
  `mixed_jvm`, `binary`. The ninth slot (`multi_version`) is added
  in #22. (#20)
- Root-level `.bazelignore` so `//...` evaluation at the repo root
  does not recurse into per-example `MODULE.bazel` files. (#20)
- Root-level `REPO.bazel` declaring `default_visibility =
  ["//visibility:public"]`. (#20)

### Documentation

- README leads with `git_override` against a pinned commit (the only
  way to consume the fork today; BCR publish is tracked separately).
  Adds a "Pinning a Groovy version" subsection that walks the
  `--@rules_groovy//groovy/config_settings:groovy_version` flag with
  the `examples/multi_version/` snippet, and a "Using rules_groovy in
  air-gapped or offline environments" section that points at the new
  `docs/airgapped.md`. All `load()` snippets switched from the legacy
  `groovy/groovy.bzl` path to the canonical
  `@rules_groovy//groovy:defs.bzl` introduced by #26. (#27)
- `docs/airgapped.md`: enumeration of every external download
  (Groovy SDK + JUnit 4/5 + Spock + Hamcrest + JUnit-5 platform
  transitive set), the known override gaps, and three end-to-end
  `MODULE.bazel` recipes (restricted-egress mirror, full air-gap via
  `rules_jvm_external` against internal Nexus, BYO SDK via
  `groovy.local_toolchain`). (#27)

### Changed

- New canonical public load surface at `@rules_groovy//groovy:defs.bzl`.
  Every user-facing symbol (`groovy_library`, `groovy_and_java_library`,
  `groovy_binary`, `groovy_test`, `groovy_junit_test`,
  `groovy_junit5_test`, `spock_test`, `groovy_runtime`,
  `groovy_toolchain`, `groovy_deps`, `GroovyToolchainInfo`,
  `GroovyDepsInfo`, `GroovyLibraryInfo`, `path_to_class`) loads from a
  single `.bzl`. Implementations split into one-responsibility files
  under `groovy/private/` (`library.bzl`, `binary.bzl`, `test.bzl`,
  `runtime.bzl`, `toolchain.bzl`). `groovy/groovy.bzl` and
  `groovy/toolchain.bzl` keep working as deprecated back-compat shims
  that re-export from `defs.bzl`; they are slated for removal in a
  future release. README, `examples/*/BUILD.bazel`, internal `tests/`,
  Stardoc inputs, and the extension-generated hub repo all point at
  `defs.bzl`. (#26)
- Public macros (`groovy_binary`, `groovy_and_java_library`,
  `groovy_test`, `groovy_junit_test`, `groovy_junit5_test`,
  `spock_test`) are now Bazel-8+ symbolic macros (`macro(...)`)
  rather than legacy `def`-based macros. Caller signatures are
  unchanged; downstream BUILD files keep working without edits.
  Wins: explicit `name`/`visibility` params in impl functions,
  typed `attrs` with `configurable = False` where appropriate,
  and macro-scoped visibility — internal scaffolding targets
  generated by the macros (e.g. `<name>-groovylib`,
  `<name>_groovy_sdk_runtime`, `<name>_lib`) are no longer
  reachable from outside the macro's defining package by default.
  `groovy_library` and `groovy_runtime` remain rules and are
  unchanged. `inherit_attrs = native.java_binary` for `groovy_binary`
  was attempted but does not work under Bazel 9.1 (rules_java's
  exported `java_binary` is a legacy `def`-based wrapper and
  `native.java_binary`'s inheritable attr surface is empty), so the
  binary's `java_binary` attrs are declared explicitly on the macro
  and forwarded through; see the PR body for the gap surfaced.
  Closes ISSUE-067. (#25)
- `groovy_library` is now a single rule (not a macro+rule pair). It
  returns `JavaInfo` directly, accepts mixed `.groovy` and `.java`
  srcs natively via groovyc joint compilation, and gains standard
  JVM-rule attrs: `runtime_deps`, `exports`, `data`, `resources`,
  `neverlink`, `plugins`. Shape matches `rules_kotlin`'s
  `kt_jvm_library`. (#21)
- `groovy_library` re-exports the active toolchain's Groovy SDK
  runtime jar via `JavaInfo.exports`, so any consumer
  (`java_library`, `java_binary`, `java_test`, another
  `groovy_library`) sees `groovy.lang.*` on both compile and runtime
  classpath without naming `@groovy_sdk_artifact//:groovy` by literal
  label. (#21)
- `groovy_binary` still wraps `rules_java`'s `java_binary` macro;
  the Groovy SDK runtime jar enters the binary's classpath via a
  hidden `_groovy_sdk_runtime` helper rule that reads
  `groovy_info.runtime_jar` off the toolchain. The
  rules-java-launcher coupling is documented and scoped to a v0.2
  follow-up. (#21)
- The `groovy` module extension now sets
  `root_module_direct_deps = ["groovy_toolchains"]`. Downstream
  `MODULE.bazel` collapses to
  `use_repo(groovy, "groovy_toolchains")`. Legacy compat repos
  (`groovy_sdk_artifact`, `junit_artifact`, `spock_artifact`,
  `groovy_artifacts`, `groovy_artifact_*`, `<tag>_sdk`) stay
  internal plumbing referenced by the generated hub on the user's
  behalf. (#21)
- `bazel_skylib` is no longer marked `dev_dependency = True` in
  `MODULE.bazel`. The production BUILD files at `//groovy:BUILD`,
  `//groovy/private:BUILD`, and `//groovy/private/repositories:BUILD`
  load `@bazel_skylib//:bzl_library.bzl` at the top level (for the
  Stardoc `bzl_library` targets); marking the dep `dev_dependency`
  broke any downstream consumer the moment toolchain resolution
  touched `@rules_groovy//groovy:toolchain_type`. Caught by the new
  `examples/` integration tests. (#20)

### Deprecated

- `groovy_and_java_library` is a deprecated alias for
  `groovy_library`. Calling either is identical now that
  `groovy_library` accepts mixed `.groovy` + `.java` srcs natively.
  Removed in v0.2.0. (#21)

### Removed

- Literal `@junit_artifact`, `@spock_artifact`, and
  `@groovy_sdk_artifact` label references from `groovy/groovy.bzl`.
  Test rules (`groovy_test`, `groovy_junit_test`,
  `groovy_junit5_test`, `spock_test`) resolve JUnit / Spock /
  Jupiter / Platform / SDK jars off the toolchain's `dep_providers`
  list (`GroovyDepsInfo.name`). (#21, ISSUE-061)
- The in-tree `example/` directory and `src/test/groovy/lib/` smoke
  test. Both shared the rules' own `MODULE.bazel` and therefore could
  not catch the kind of integration bug `examples/` now catches.
  Coverage migrated:
  `example/library_basic/` → `examples/minimal_library/`;
  `example/junit4/` → `examples/junit4_test/`;
  `example/spock/` → `examples/spock_test/`;
  `example/binary/` → `examples/binary/`;
  `example/mixed_jvm/` → `examples/mixed_jvm/`;
  `example/multi_version/` (README-only) → ISSUE-064;
  `example/rules_jvm_external_interop/` (README-only) →
  `examples/maven_dep/`. The `override_url/` and `local_sdk/`
  README-only patterns are folded into the relevant new examples'
  documentation. (#20)

### Compatibility

- Bazel minimum: 9.0.
- Bzlmod only — `WORKSPACE` is no longer supported.
- Public macro names (`groovy_library`, `groovy_binary`, `groovy_test`,
  `groovy_junit_test`, `groovy_junit5_test`, `spock_test`) are
  source-level compatible with upstream `bazelbuild/rules_groovy 0.0.6`
  BUILD files. The `groovy.testing(...)` MODULE.bazel surface is
  removed; downstream modules wire JUnit / Spock via
  `rules_jvm_external` per the migration note above.

[0.1.0]: https://github.com/albertocavalcante/rules_groovy/releases/tag/v0.1.0

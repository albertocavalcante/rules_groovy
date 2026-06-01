# Hermeticity

`rules_groovy` is hermetic by construction. This document is the
audited claim — the explicit list of what hermeticity means here and
the per-action evidence for it. ADR-005 puts hermeticity in the
v0.1.0 baseline; this is the artifact that justifies the claim in the
[README](../README.md#hermeticity).

## What we mean by "hermetic"

For every compile, packaging, and test action `rules_groovy` emits:

1. **Action inputs are explicit.** Every file the action reads is
   declared in the action's `inputs = ...` or `tools = ...`. No
   reads from undeclared paths, no glob escapes outside the action's
   sandbox.
2. **Action environment is explicit.** `ctx.actions.run` is called
   with `env = {...}` containing only what the action genuinely
   needs (typically just `JAVA_HOME`). `use_default_shell_env =
   True` is never set. No `$PATH`, `$HOME`, `$USER`,
   `$GROOVY_HOME`, or `$LD_LIBRARY_PATH` leaks into action
   environments.
3. **Tools are toolchain-resolved.** `groovyc` comes from the
   registered Groovy toolchain, not from `which groovyc`. `java` /
   `jar` / `singlejar` come from Bazel's
   `java_runtime_toolchain_type` and `java_toolchain_type`. No
   hardcoded `/usr/bin/java`.
4. **Downloads are integrity-pinned.** The Groovy SDK is pinned in
   `groovy/private/versions.bzl` with a `sha256-...` integrity hash.
   Test framework jars (JUnit, Spock, etc.) come in via
   `rules_jvm_external`'s `maven.install`, which captures per-artifact
   SHAs in a committed `maven_install.json` lockfile.
5. **All URLs are overridable.** Every `urls` list, every
   `integrity` value, every `strip_prefix`, and every `lib_jar` path
   can be overridden from `MODULE.bazel` without forking the rules.

## What hermeticity does NOT mean here

- **Shell scripts use POSIX utilities.** `groovy/private/groovyc_wrapper.sh`
  invokes `/usr/bin/env`, `mktemp`, `rm`, and the JDK's `jar` tool
  (via `$JAVA_HOME/bin/jar`). The first three are assumed present on
  any Linux/macOS host that runs Bazel. The `jar` tool is found via
  the action's explicit `JAVA_HOME`.
- **The host JDK is not vendored.** `rules_groovy` resolves the JDK
  via Bazel's `java_runtime_toolchain_type`, which by default uses
  the `remotejdk_11` set Bazel ships. Consumers can register their
  own JDK toolchain to use a different version; that selection is
  exposed through the toolchain layer, not coupled to host
  installations.

## Per-action audit

| Action / surface | File | Hermeticity evidence |
|---|---|---|
| `Groovyc` compile | [`groovy/private/actions.bzl`](../groovy/private/actions.bzl) `compile_groovy` | `ctx.actions.run(...)` (not `run_shell`). `env = {"JAVA_HOME": java_runtime.java_home}`. `executable = ctx.executable.groovyc` from the toolchain. `tools` declares the SDK files via `groovy_info.sdk_files`. Param files via `use_param_file("@%s", use_always = True)`. |
| `GroovySingleJar` packaging | [`groovy/private/actions.bzl`](../groovy/private/actions.bzl) | `ctx.actions.run(...)` against `single_jar` from `JAVA_TOOLCHAIN_TYPE`. `env = {}` (singlejar is a hermetic native binary; needs no env). `--add_missing_directories` for `java_library` parity. `--normalize` for deterministic ordering. |
| `Descriptor Set` / `Java headers` etc. | upstream `rules_java` actions | Inherit `rules_java`'s hermeticity contract; nothing in `rules_groovy` modifies these. |
| `groovyc_wrapper.sh` | [`groovy/private/groovyc_wrapper.sh`](../groovy/private/groovyc_wrapper.sh) | No `which` / `command -v`. SDK located via `external/*/groovy-*/bin/groovyc` glob — runfiles tree, not host. `jar` tool via explicit `$JAVA_HOME/bin/jar`. `set -eu` for fail-fast on missing env. |
| `groovy_test` launcher | [`groovy/private/test.bzl`](../groovy/private/test.bzl) | `runner_class` set per-rule (mandatory attr; convenience macros hardcode the framework FQCN). Java runtime from `JDK_RUNTIME_TOOLCHAIN_TYPE`. Classpath from the toolchain's SDK file set + `ctx.attr.deps`. Test framework jars come in via `deps` — typically resolved by `rules_jvm_external`'s lockfile-pinned `maven.install`. No host reads. |
| `groovy_binary` / `_groovy_sdk_runtime` | [`groovy/private/binary.bzl`](../groovy/private/binary.bzl) + [`groovy/private/runtime.bzl`](../groovy/private/runtime.bzl) | Wraps `rules_java`'s `java_binary`. The hidden `groovy_sdk_runtime` helper rule produces a `JavaInfo` over the toolchain's runtime jar; no host JARs, no host classpath. |
| `groovy_library` | [`groovy/private/library.bzl`](../groovy/private/library.bzl) | Calls `compile_groovy` (audited above). Folds `sdk_runtime_javainfo(ctx)` into the library's `exports` so `groovy.lang.*` types reach every consumer transitively without naming `@groovy_sdk_artifact` by literal label. |
| `groovy_sdk_repository` (download path) | [`groovy/private/repositories/sdk.bzl`](../groovy/private/repositories/sdk.bzl) | `http_archive`-shape repository rule. URL list comes from `versions.bzl` or the consumer's `groovy.toolchain(urls = ...)` override. Integrity hash is mandatory for unknown versions. |
| `groovy_local_sdk_repository` (BYO-SDK path) | [`groovy/private/repositories/sdk.bzl`](../groovy/private/repositories/sdk.bzl) | Symlinks `sdk_path` as `groovy-<version>/` so the launcher's glob resolves the same way. Best-effort `rctx.path(in_repo_lib_jar).exists` check with a path-specific error if `<sdk_path>/<lib_jar>` is missing. |

## Automated checks

Two examples and one analysistest cover the runtime claim.

- [`tests/hermeticity_test.bzl`](../tests/hermeticity_test.bzl) —
  Skylib `analysistest` that introspects the `Groovyc` action's
  `mnemonic`, `env`, and `argv`. Asserts: `Groovyc` and
  `GroovySingleJar` mnemonics are present (i.e. compile + package
  ran through `ctx.actions.run`, not `run_shell`); the `Groovyc`
  action's `env` contains a non-empty `JAVA_HOME` and **none of**
  `PATH` / `HOME` / `USER` / `GROOVY_HOME` / `LD_LIBRARY_PATH`. A
  regression that flipped `use_default_shell_env = True` would
  surface as either a missing `JAVA_HOME` or a present host-env key
  on the action.
- [`examples/reproducibility/`](../examples/reproducibility/) —
  builds a one-class `groovy_library` and asserts byte-equality of
  the output jar across cold and warm builds via `bazel-skylib`'s
  `diff_test`. Catches non-determinism in the `Groovyc` →
  `GroovySingleJar` chain (timestamps, manifest ordering,
  META-INF/services merge order).
- [`examples/local_toolchain/`](../examples/local_toolchain/) —
  closes the air-gap path: `groovy.local_toolchain(sdk_path = ...)`
  resolves a host-installed SDK without any network access at
  toolchain-resolve time. Combined with `--repository_cache` for
  any remaining transitive Bazel deps, this is what a fully-offline
  build looks like.

## What the audit did not (yet) cover

- **Sandbox-mode robustness.** The `examples/reproducibility/`
  check runs with whatever sandbox strategy Bazel selects by
  default. Future work: explicit smoke under `--spawn_strategy=
  sandboxed`, `linux-sandbox`, `processwrapper-sandbox`, and
  `darwin-sandbox`.
- **PATH-stripped action env.** `bazel build --action_env=PATH=` (empty)
  exposes whether the wrapper script tolerates a minimal PATH. The
  wrapper does not read `$PATH` itself, but `/usr/bin/env` and
  shell builtins do. Worth confirming under explicit PATH-strip.
- **Manifest determinism on the `groovy_binary` deploy jar.** The
  wrapping `java_binary` rule emits the deploy jar; we have not
  separately verified its manifest is timestamp-free.

These are queued as v0.2 follow-ups, not blockers on v0.1.0.

## Reading order

If you're auditing the hermeticity claim yourself:

1. [`groovy/private/actions.bzl`](../groovy/private/actions.bzl)
   module docstring — enumerated checkpoints.
2. [`tests/hermeticity_test.bzl`](../tests/hermeticity_test.bzl)
   — the analysistest that catches regressions on the explicit
   `JAVA_HOME` + no-host-env-leak contract.
3. [`groovy/private/groovyc_wrapper.sh`](../groovy/private/groovyc_wrapper.sh)
   — the only shell script in the action path; check the SDK
   resolution and `jar` tool wiring.
4. The per-action audit table above for the rest.

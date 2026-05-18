# multi_version

Three Groovy SDKs registered in the same `MODULE.bazel`; one
`groovy_library` + one `groovy_junit_test` target. The build flag
`@rules_groovy//groovy/config_settings:groovy_version` picks which SDK
both compiles the library and runs the test.

This is the example restored from PR #20's deferred state in PR #22
(ISSUE-064 — before the hub generator emitted `config_setting`s and
per-toolchain `target_settings`, all three registered toolchains
resolved to the first one in the list and the others were
unreachable).

The test target was added in ISSUE-071: previously the example
build-only-tested the per-version selection, which masked the fact
that the toolchain folded Spock 1.3-groovy-2.5 onto every compile
classpath and broke as soon as the `groovy_version` flag selected
Groovy 3.0 or 4.0. The test now exercises both compilation *and*
runtime under each SDK.

## Four invocations

```
# Default — no flag, picks the toolchain whose version equals
# DEFAULT_GROOVY_VERSION (currently 4.0.32) via its `:is_default`
# registration.
bazel test //...

# Explicit Groovy 4.0.32 — same toolchain as the default, but pinned
# by value rather than `:is_default`.
bazel test --@rules_groovy//groovy/config_settings:groovy_version=4.0.32 //...

# Explicit Groovy 3.0.25.
bazel test --@rules_groovy//groovy/config_settings:groovy_version=3.0.25 //...

# Explicit Groovy 2.5.23.
bazel test --@rules_groovy//groovy/config_settings:groovy_version=2.5.23 //...
```

`bazel build --toolchain_resolution_debug=...` confirms which
`groovy_toolchain` actually matched toolchain resolution in each case:

```
$ bazel build //:lib \
    --@rules_groovy//groovy/config_settings:groovy_version=2.5.23 \
    --toolchain_resolution_debug='rules_groovy.*:toolchain_type'
... Selected toolchain @@rules_groovy++groovy+groovy_toolchains//:groovy_2_5_23 ...
```

Unknown values fail with the standard Bazel "no matching toolchains"
error:

```
$ bazel build --@rules_groovy//groovy/config_settings:groovy_version=99.99.99 //:lib
ERROR: ... While resolving toolchains for target //:lib (...):
       No matching toolchains found for types @@rules_groovy+//groovy:toolchain_type.
```

## What this proves

- The hub repo emits one `config_setting` per registered SDK keyed
  off the `groovy_version` flag, plus an `:is_default` setting matching
  the empty-string flag default. Each `toolchain(...)` declaration
  gates on the matching setting via `target_settings`.
- The SDK whose `version` equals `DEFAULT_GROOVY_VERSION` registers
  twice — once on its own version setting (for explicit pinning to
  the default value) and once on `:is_default` (for the no-flag
  case). Both registrations point at the same underlying
  `groovy_toolchain`.
- Per-target selection (different libraries pinning different Groovy
  versions in the same build) is out of scope for v0.1.0. That
  requires either platforms machinery or an attr-level transition on
  the rule; tracked as a v0.2 follow-up.

## Why JUnit 4 and not Spock or JUnit 5

This example deliberately does *not* exercise Spock or JUnit 5. Both
fall apart when the same MODULE.bazel registers Groovy SDKs across
major versions:

- **Spock** ships its compiler plugin as a global Groovy AST
  transform, pinned to one Groovy major.minor. The toolchain selects
  the Spock release matching the first registered SDK and folds it
  onto every compile classpath; groovyc auto-loads the global
  transform and explodes with `IncompatibleGroovyVersionException` as
  soon as the `groovy_version` flag selects a different Groovy major.
  See `examples/spock_test/` for the single-major Spock pattern.
- **JUnit 5** would work on the compile side (Jupiter is plain
  annotations) but each Groovy SDK distribution bundles its own copy
  of the JUnit Platform jars under `lib/` (Groovy 2.5: Platform 1.4.2;
  Groovy 3.0: 1.12.0; Groovy 4.0: 1.13.3). Those land on the runtime
  classpath via the toolchain's `sdk_files` and clash with the
  toolchain's pinned Platform 1.14.4, producing `NoSuchMethodError`
  at `ConsoleLauncher` startup.

JUnit 4 (`org.junit.runner.JUnitCore`) is the lowest-common-denominator
runner that survives all three SDKs: `junit-4.13.2.jar` is bundled
identically inside Groovy 2.5 / 3.0 / 4.0 and matches the toolchain's
pinned JUnit 4 artifact.

The v0.2 architectural refactor (see
`rules_groovy-plan/notes/roadmap-v0.1-v0.2.md`) drops the
`groovy.testing` tag class entirely and moves test framework deps to
user-supplied `rules_jvm_external` deps; that change removes the whole
implicit-promotion path that makes the Spock / JUnit-5 combinations
fragile here.

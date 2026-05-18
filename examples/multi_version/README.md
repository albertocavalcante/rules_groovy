# multi_version

Three Groovy SDKs registered in the same `MODULE.bazel`; one
`groovy_library` target. The build flag
`@rules_groovy//groovy/config_settings:groovy_version` picks which
SDK compiles the library.

This is the example deferred from PR #20 (chapter 12 of the v0.1.0
release narrative). The deferral was tracked as ISSUE-064: before the
hub generator emitted `config_setting`s and per-toolchain
`target_settings`, all three registered toolchains resolved to the
first one in the list and the others were unreachable. PR #22 closes
that gap.

## Three invocations

```
# Default — no flag, picks the toolchain whose version equals
# DEFAULT_GROOVY_VERSION (currently 4.0.32) via its `:is_default`
# registration.
bazel build //:lib

# Explicit Groovy 3.0.25.
bazel build --@rules_groovy//groovy/config_settings:groovy_version=3.0.25 //:lib

# Explicit Groovy 2.5.23.
bazel build --@rules_groovy//groovy/config_settings:groovy_version=2.5.23 //:lib
```

`bazel cquery` confirms which `groovy_toolchain` rule actually matched
toolchain resolution in each case:

```
$ bazel cquery --output=label_kind \
    'deps(//:lib) intersect kind("groovy_toolchain rule", //...)' --keep_going
# Default flag:
groovy_toolchain rule @@+groovy+groovy_toolchains//:groovy_4_0_32

# --groovy_version=3.0.25:
groovy_toolchain rule @@+groovy+groovy_toolchains//:groovy_3_0_25

# --groovy_version=2.5.23:
groovy_toolchain rule @@+groovy+groovy_toolchains//:groovy_2_5_23
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

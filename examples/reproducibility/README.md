# reproducibility

A one-class `groovy_library` whose output jar is hashed and compared
against a checked-in golden via `bazel-skylib`'s `diff_test`. If the
jar drifts between builds, `bazel test //...` fails.

```
bazel test //...
```

What this proves: the chain of actions `groovy_library` emits
(`Groovyc` → `GroovySingleJar`) produces a byte-identical jar across
cold and warm builds on the same platform. `singlejar --normalize
--exclude_build_data` is the guarantee — timestamps inside the zip
are stamped to `2010-01-01 00:00`, entry order is canonical, and
`Build-Data` lines are stripped from the manifest.

## Caveat — cross-platform fragility

The golden hash (`golden_jar_sha256.txt`) was seeded on macOS / arm64
with `remotejdk_11`. The jar contents are nominally platform-
independent (pinned Groovy SDK, pinned remote JDK), but if Groovyc
ever ships an AST-transform output whose iteration order depends on
JVM `HashMap` internals (a known historical class of Groovy-compiler
non-determinism), the Linux CI hash will differ from the seeded
golden.

If CI fails the diff, the right response is **not** to delete the
assertion. Either:

1. Re-seed `golden_jar_sha256.txt` from the failing CI run and accept
   that the golden is OS-specific (and split it per-OS in the matrix).
2. File a fork-level issue against `actions.bzl` to investigate the
   non-determinism source (a real bug worth tracking).

## Re-seeding the golden

```
bazel clean
bazel build //:hello
shasum -a 256 bazel-bin/libhello.jar | cut -d' ' -f1 > golden_jar_sha256.txt
```

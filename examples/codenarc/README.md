# codenarc

[CodeNarc](https://codenarc.org/) static analysis for Groovy sources,
wired as `bazel test //:codenarc` via a `java_binary` + `sh_test` pair.

```
bazel test //:codenarc --test_output=all
```

## What this proves

CodeNarc is itself a Groovy program — running it under a plain
`java_binary` requires Groovy on the binary's runtime classpath. PR
\#23 / ISSUE-065 adds the stable label `@rules_groovy//groovy:runtime`,
a `JavaInfo`-providing target backed by the active Groovy toolchain's
resolved runtime jar. Listing it in `runtime_deps` puts the
toolchain's Groovy on the classpath without the consumer naming any
`@groovy_sdk_artifact//...` internal repo name (the workaround the
Jenkins-shared-library stress test had to apply pre-PR-#23).

```python
java_binary(
    name = "codenarc_cli",
    main_class = "org.codenarc.CodeNarc",
    runtime_deps = [
        "@maven//:org_codenarc_CodeNarc",
        "@rules_groovy//groovy:runtime",   # toolchain-resolved SDK jar
    ],
)
```

Per-version selection (PR #22) works transparently. Setting
`--//groovy:groovy_version=3.0.25` (or whichever value is registered)
flips the toolchain Bazel resolves, and `@rules_groovy//groovy:runtime`
picks up that toolchain's jar — no rule-level change required.

## Layout

```
examples/codenarc/
  MODULE.bazel               # local_path_override on ../..
  BUILD.bazel                # groovy_library + codenarc_cli + codenarc sh_test
  README.md                  # this file
  codenarc.groovy            # the ruleset (basic / imports / naming / unused)
  codenarc.sh                # CodeNarc launcher invoked by sh_test
  src/main/groovy/lib/
    Greeter.groovy           # a small clean class the ruleset passes against
```

## Out of scope

Upstreaming a CodeNarc aspect into
[`aspect-build/rules_lint`](https://github.com/aspect-build/rules_lint)
— tracked separately as ISSUE-066. This example is the canonical
local pattern in the meantime.

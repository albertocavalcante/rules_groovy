# spock

`spock_test` with the default Spock setup. The Spock jar matched to the
active Groovy major.minor is wired automatically by the module
extension.

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_library", "spock_test")

groovy_library(
    name = "calc",
    srcs = ["src/main/groovy/calc/Calc.groovy"],
)

spock_test(
    name = "CalcSpec",
    specs = ["src/test/groovy/calc/CalcSpec.groovy"],
    src_roots = [
        "example/spock/src/test/groovy",
        "example/spock/src/test/java",
    ],
    deps = [":calc"],
)
```

What to look for: the `where:` data-driven table is pure Spock; if
`@spock_artifact` weren't on the classpath, the spec wouldn't even
compile.

The target is tagged `manual` for v0.1.0. The Spock jar paired with
Groovy 4.0 is Spock 2.x, which discovers specs through the JUnit 5
Platform; the `spock_test` macro currently launches JUnit 4's
`JUnitCore`, so no specs are found at runtime. A JUnit 5 launcher
path is on the v0.2 roadmap. Until then, build-only verification:

```
bazel build //example/spock:CalcSpec
```

Pinning Groovy 2.5 via `groovy.toolchain(version = "2.5.23")` selects
Spock 1.3 — which runs cleanly under JUnit 4 — if you need
end-to-end execution today.

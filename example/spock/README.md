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

Under the Groovy 4 default the matched Spock is 2.3, which discovers
specs through the JUnit 5 Platform. The module extension promotes the
resolved testing flavor to JUnit 5 and points the toolchain's
`runner_class` at `org.junit.platform.console.ConsoleLauncher`; the
`spock_test` macro routes through that launcher with no per-target
wiring. Pinning Groovy 2.5 via `groovy.toolchain(version = "2.5.23")`
selects Spock 1.3 instead, which keeps the JUnit 4 launcher path.

Run it:

```
bazel test //example/spock:CalcSpec
```

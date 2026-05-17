load("//groovy:groovy.bzl", "groovy_library", "spock_test")

groovy_library(
    name = "calc",
    srcs = ["src/main/groovy/calc/Calc.groovy"],
)

# `src_roots` matches the example-relative source-root paths so the Spock
# spec is reachable from this package instead of from `src/test/groovy/`
# at the workspace root.
#
# The Spock jar matched to Groovy 4.0 is Spock 2.3, which runs on the
# JUnit 5 Platform. The module extension promotes the testing flavor to
# JUnit 5 automatically (`SPOCK_FOR_GROOVY["4.0"].junit_flavor == "5"`)
# and sets the toolchain's `runner_class` to
# `org.junit.platform.console.ConsoleLauncher`; the `spock_test` macro
# routes the spec through that launcher with no per-target wiring.
spock_test(
    name = "CalcSpec",
    specs = ["src/test/groovy/calc/CalcSpec.groovy"],
    src_roots = [
        "example/spock/src/test/groovy",
        "example/spock/src/test/java",
    ],
    deps = [":calc"],
)

load("//groovy:groovy.bzl", "groovy_library", "spock_test")

groovy_library(
    name = "calc",
    srcs = ["src/main/groovy/calc/Calc.groovy"],
)

# `src_roots` matches the example-relative source-root paths so the Spock
# spec is reachable from this package instead of from `src/test/groovy/`
# at the workspace root.
#
# Tagged `manual` for now: the Spock jar matched to Groovy 4.0 is Spock
# 2.3, which only runs under the JUnit 5 Platform engine. The
# `spock_test` macro currently launches `org.junit.runner.JUnitCore`
# (JUnit 4), so the spec compiles and links but no specs are discovered
# at runtime. A JUnit 5 launcher path lands with ISSUE-023; until then
# this example is build-only. `bazel build //example/spock:CalcSpec`
# exercises the full compile / link / classpath wiring.
spock_test(
    name = "CalcSpec",
    specs = ["src/test/groovy/calc/CalcSpec.groovy"],
    src_roots = [
        "example/spock/src/test/groovy",
        "example/spock/src/test/java",
    ],
    tags = ["manual"],
    deps = [":calc"],
)

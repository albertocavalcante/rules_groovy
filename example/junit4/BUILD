load("//groovy:groovy.bzl", "groovy_junit_test", "groovy_library")

groovy_library(
    name = "calc",
    srcs = ["src/main/groovy/calc/Calc.groovy"],
)

# `src_roots` is required here: the test source lives under
# `example/junit4/src/test/groovy/...`, not the workspace-root
# `src/test/groovy/...` the macro defaults to.
groovy_junit_test(
    name = "CalcTest",
    src_roots = [
        "example/junit4/src/test/groovy",
        "example/junit4/src/test/java",
    ],
    tests = ["src/test/groovy/calc/CalcTest.groovy"],
    deps = [":calc"],
)

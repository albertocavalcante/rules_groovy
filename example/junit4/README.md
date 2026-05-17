# junit4

`groovy_junit_test` driving a JUnit 4 spec. Note the `src_roots`
attribute — it tells the macro where to slice the FQCN prefix from each
source path.

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_junit_test", "groovy_library")

groovy_library(
    name = "calc",
    srcs = ["src/main/groovy/calc/Calc.groovy"],
)

groovy_junit_test(
    name = "CalcTest",
    src_roots = [
        "example/junit4/src/test/groovy",
        "example/junit4/src/test/java",
    ],
    tests = ["src/test/groovy/calc/CalcTest.groovy"],
    deps = [":calc"],
)
```

What to look for: without `src_roots`, the macro would try to strip the
workspace-root prefix `src/test/groovy/` from `example/junit4/src/test/groovy/calc/CalcTest.groovy`
and fail. Setting `src_roots` to the example-relative paths lets the
test live under its own package.

Run it:

```
bazel test //example/junit4:CalcTest
```

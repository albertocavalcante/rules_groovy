# mixed_jvm

Groovy and Java sources in the same library.

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_and_java_library")

groovy_and_java_library(
    name = "mixed",
    srcs = [
        "src/main/groovy/mixed/Caller.groovy",
        "src/main/java/mixed/Helper.java",
    ],
)
```

`groovy_and_java_library` partitions `srcs` by extension and routes each
half through its native compiler. The Groovy half sees Java types
(`Caller.groovy` calls `Helper.compute()`); the Java half does not see
Groovy.

To express the inverse (Java depending on Groovy), split into two
targets with an explicit `deps` edge — see `:lib_groovy` and
`:java_calls_groovy` in this BUILD.

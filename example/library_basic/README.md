# library_basic

Single `groovy_library` target with one `.groovy` source. The smallest
useful shape for the rule set.

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_library")

groovy_library(
    name = "greeter",
    srcs = ["src/main/groovy/greeter/Greeter.groovy"],
)
```

What to look for: the resulting `libgreeter-impl.jar` is wrapped in a
`java_import` named `greeter` so plain `java_library` and `java_binary`
targets can depend on it without any Groovy-specific glue.

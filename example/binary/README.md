# binary

Runnable Groovy application via `groovy_binary`.

```python
load("@rules_groovy//groovy:groovy.bzl", "groovy_binary")

groovy_binary(
    name = "app",
    srcs = ["src/main/groovy/app/App.groovy"],
    main_class = "app.App",
)
```

Run it:

```
bazel run //example/binary:app
```

What to look for: the underlying `java_binary` resolves the Groovy
runtime through the toolchain — the BUILD lists no `@groovy_sdk_artifact`
runtime_dep itself.

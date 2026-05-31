# minimal_library

The smallest meaningful downstream consumer: one `groovy_library` with a
single Groovy source and no deps. Runs `groovyc` through the active
toolchain and packages the output into a `java_import`.

```
bazel build //...
```

What this proves: `bazel_dep(name = "rules_groovy")` resolves, the
implicit-default `groovy` extension fires (`groovy_sdk_artifact`,
`junit_artifact`, `spock_artifact`, `groovy_toolchains`), and the
canonical `load("@rules_groovy//groovy:defs.bzl", ...)` path works
end-to-end from a module that is not `rules_groovy` itself.

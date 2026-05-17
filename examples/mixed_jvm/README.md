# mixed_jvm

Groovy and Java sources compiled together. Three shapes:

- `:mixed` — single `groovy_and_java_library` target with both
  extensions in `srcs`; the macro partitions internally.
- `:lib_groovy` / `:lib_java` — two separate targets with an explicit
  `deps` edge; Groovy depends on Java.
- `:java_calls_groovy` — a `java_library` consuming the Groovy half,
  which requires the Groovy SDK jar on its compile classpath.

```
bazel build //...
bazel test //...
```

What this proves: groovyc accepts mixed-source compilation so Groovy
may reference Java types in either layout. The test target invokes
`Caller.callHelper()` to verify the cross-language wire-up runs.

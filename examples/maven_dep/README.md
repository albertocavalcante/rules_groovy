# maven_dep

Pulls a real Maven artifact (Guava 33.4.0-jre) via `rules_jvm_external`,
consumes it from a `groovy_library`, and exercises it from a
`groovy_junit5_test`.

```
bazel test //...
```

What this proves: `rules_groovy` itself does not depend on
`rules_jvm_external`, but the two compose cleanly when downstream
modules opt in. `@maven//:com_google_guava_guava` flows through
`groovy_library.deps` like any other `JavaInfo`-providing label.

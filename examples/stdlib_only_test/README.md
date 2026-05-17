# stdlib_only_test

A `groovy_junit5_test` whose source uses only Groovy idioms (GStrings,
list literals, `.inject {}`) and JDK stdlib types. No external Maven
dependencies beyond the JUnit jars the ruleset wires up automatically
through `groovy.testing` (JUnit 5 path by default on Groovy 4.0).

```
bazel test //...
```

What this proves: the JUnit 5 console launcher path runs end-to-end
without any user-declared `bazel_dep` on JUnit, `rules_jvm_external`, or
`@maven`. The default extension on Groovy 4.0 auto-promotes the testing
flavor to JUnit 5 because Spock 2.x requires it.

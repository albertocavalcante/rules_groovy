# junit5_test

A `groovy_junit5_test` against JUnit 5 Jupiter. Source uses
`@org.junit.jupiter.api.Test` and `org.junit.jupiter.api.Assertions`.
Runs through `org.junit.platform.console.ConsoleLauncher`.

```
bazel test //...
```

What this proves: the JUnit 5 path runs end-to-end on the rules' default
Groovy 4.0 toolchain. The default extension auto-promotes the testing
flavor to JUnit 5 because Spock 2.x runs on the JUnit Platform, so the
console launcher's classpath (jupiter-api, jupiter-engine,
platform-launcher / platform-engine / platform-commons, opentest4j,
apiguardian-api) is wired up without any user-declared `bazel_dep` on
JUnit.
